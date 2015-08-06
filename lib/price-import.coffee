debug = require('debug')('sphere-price-import')
_ = require 'underscore'
_.mixin require 'underscore-mixins'
Promise = require 'bluebird'
slugify = require 'underscore.string/slugify'
{SphereClient, ProductSync} = require 'sphere-node-sdk'
{Repeater} = require 'sphere-node-utils'
ProductImport = require './product-import'

class PriceImport extends ProductImport

  constructor: (@logger, options = {}) ->
    super @logger, options
    @sync.config [{type: 'prices', group: 'white'}].concat(['base', 'references', 'attributes', 'images', 'variants', 'metaAttributes'].map (type) -> {type, group: 'black'})
    @repeater = new Repeater

  _resetSummary: ->
    @_summary =
      unknownSKUCount: 0
      duplicatedSKUs: 0
      variantWithoutPriceUpdates: 0
      updated: 0

  summaryReport: ->
    if @_summary.updated is 0
      message = 'Summary: nothing to update'
    else
      message = "Summary: there were #{@_summary.updated} price update(s)." +
        "(unknown skus: #{@_summary.unknownSKUCount}, duplicate skus: #{@_summary.duplicatedSKUs}, variants without price updates: #{@_summary.variantWithoutPriceUpdates})"

    message

  _processBatches: (prices) ->
    batchedList = _.batchList(prices, 30) # max parallel elements to process
    Promise.map batchedList, (pricesToProcess) =>
      skus = _.map pricesToProcess, (p) -> p.sku
      predicate = @_createProductFetchBySkuQueryPredicate skus
      @client.productProjections
      .where predicate
      .staged true
      .all()
      .fetch()
      .then (results) =>
        debug "Fetched products: %j", results
        queriedEntries = results.body.results
        wrappedProducts = @_wrapPricesIntoProducts pricesToProcess, queriedEntries
        console.log "Wrapped #{_.size prices} price(s) into #{_.size wrappedProducts} existing product(s)."
        @_createOrUpdate wrappedProducts, queriedEntries
        .then (results) =>
          _.each results, (r) =>
            switch r.statusCode
              when 200 then @_summary.updated++
          Promise.resolve(@_summary)
    ,{concurrency: 1}

  _createOrUpdate: (productsToProcess, existingProducts) ->
    debug 'Products to process: %j', {toProcess: productsToProcess, existing: existingProducts}

    posts = _.map productsToProcess, (prodToProcess) =>
      existingProduct = @_isExistingEntry(prodToProcess, existingProducts)
      if existingProduct?
        synced = @sync.buildActions(prodToProcess, existingProduct)
        if synced.shouldUpdate()
          updateTask = (payload) =>
            @client.products.byId(synced.getUpdateId()).update(payload)
          @repeater.execute ->
            updateTask(synced.getUpdatePayload())
          , (e) =>
            if e.statusCode is 409
              debug 'retrying to update %s because of 409', synced.getUpdateId()
              newTask = =>
                @client.productProjections.staged(true)
                .byId(synced.getUpdateId())
                .fetch()
                .then (result) ->
                  newPayload = _.extend {}, synced.getUpdatePayload(), {version: result.body.version}
                  updateTask(newPayload)
              Promise.resolve(newTask)
            else Promise.reject(e) # do not retry in this case
        else
          Promise.resolve statusCode: 304
      else
        @_summary.unknownSKUCount++
        Promise.resolve statusCode: 404

    debug 'About to send %s requests', _.size(posts)
    Promise.all(posts)

  _wrapPricesIntoProducts: (prices, products) ->
    sku2index = {}
    _.each prices, (p, index) =>
      if not _.has(sku2index, p.sku)
        sku2index[p.sku] = index
      else
        @logger.warn "Duplicate SKU found - '#{p.sku}' - ignoring!"
        @_summary.duplicatedSKUs++

    _.map products, (p) =>
      product = _.deepClone p
      @_wrapPricesIntoVariant product.masterVariant, prices, sku2index
      _.each product.variants, (v) =>
        @_wrapPricesIntoVariant v, prices, sku2index
      product

  _wrapPricesIntoVariant: (variant, prices, sku2index) ->
    if _.has(sku2index, variant.sku)
      index = sku2index[variant.sku]
      variant.prices = _.deepClone prices[index].prices
    else
      @_summary.variantWithoutPriceUpdates++

module.exports = PriceImport