debug = require('debug')('sphere-price-import')
_ = require 'underscore'
_.mixin require 'underscore-mixins'
Promise = require 'bluebird'
slugify = require 'underscore.string/slugify'
{SphereClient, ProductSync} = require 'sphere-node-sdk'
ProductImport = require './product-import'

class PriceImport extends ProductImport

  constructor: (@logger, options = {}) ->
    @sync = new ProductSync
    @sync.config [{type: 'prices', group: 'white'}].concat(['base', 'references', 'attributes', 'images', 'variants', 'metaAttributes'].map (type) -> {type, group: 'black'})
    @client = new SphereClient options
    @_resetSummary()

  _resetSummary: ->
    @_summary =
      emptySKU: 0
      unknownSKUCount: 0
      created: 0
      updated: 0


  performStream: (chunk, cb) ->
    @_processBatches(chunk).then -> cb()

  @_processBatches: (prices) ->
    batchedList = _.batchList(prices, 30) # max parallel elements to process
    Promise.map batchedList, (pricesToProcess) =>
      skus = @_extractUniqueSkus(pricesToProcess)
      predicate = @_createProductFetchBySkuQueryPredicate(skus)
      @client.productProjections
      .where(predicate)
      .staged(true)
      .fetch()
      .then (results) =>
        debug 'Fetched products: %j', results
        queriedEntries = results.body.results
        @_wrapPricesIntoProducts(pricesToProcess, queriedEntries)
        .then (wrappedProducts) =>
          @_createOrUpdate wrappedProducts, queriedEntries
          .then (results) =>
            _.each results, (r) =>
              switch r.statusCode
                when 201 then @_summary.created++
                when 200 then @_summary.updated++
            Promise.resolve()
    ,{concurrency: 1}

  _wrapPricesIntoProducts: (prices, products) ->
    sku2index = {}
    _.each prices.prices, (p, index) ->
      if not _.has(sku2index, p.sku)
        sku2index[p.sku] = []
      sku2index[p.sku].push index
    console.log "sku2index", sku2index

    _.each products.products, (p) =>
      @_wrapPriceIntoVariant p.masterVariant, prices.prices, sku2index
      _.each p.variants, (v) =>
        @_wrapPriceIntoVariant v, prices.prices, sku2index

  _wrapPriceIntoVariant: (variant, prices, sku2index) ->
    if _.has(sku2index, variant.sku)
      variant.prices = []
      _.each sku2index[variant.sku], (index) ->
        price = _.deepClone prices[index]
        delete price.sku
        variant.prices.push price

module.exports = PriceImport