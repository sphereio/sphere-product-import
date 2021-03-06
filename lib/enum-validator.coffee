debug = require('debug')('sphere-product-import:enum-validator')
_ = require 'underscore'
_.mixin require 'underscore-mixins'
Promise = require 'bluebird'
slugify = require 'underscore.string/slugify'
{SphereClient} = require 'sphere-node-sdk'

class EnumValidator

  constructor: (@logger) ->
    @_resetCache()
    debug "Enum Validator initialized."

  _resetCache: ->
    @_cache =
      productTypeEnumMap: {}
      generatedEnums: {}

  validateProduct: (product, resolvedProductType) =>
    enumAttributes = @_fetchEnumAttributesFromProduct(product, resolvedProductType)
    updateActions = @_validateEnums(enumAttributes, resolvedProductType)
    update =
      productTypeId: resolvedProductType.id
      actions: updateActions
    update

  _validateEnums: (enumAttributes, productType) =>
    updateActions = []
    referenceEnums = @_fetchEnumAttributesOfProductType(productType)
    for ea in enumAttributes
      if not @_isEnumGenerated(ea)
        @_handleNewEnumAttributeUpdate(ea, referenceEnums, updateActions, productType)
      else
        debug "Skipping #{ea.name} update action generation as already exists."
    updateActions

  _handleNewEnumAttributeUpdate: (ea, referenceEnums, updateActions, productType) =>
    refEnum = _.findWhere(referenceEnums, {name: "#{ea.name}"})
    if refEnum and not @_isEnumKeyPresent(ea, refEnum)
      updateActions.push @_generateUpdateAction(ea, refEnum)
    else
      debug "enum attribute name: #{ea.name} not found in Product Type: #{productType.name}"

  _isEnumGenerated: (ea) =>
    @_cache.generatedEnums["#{ea.name}-#{slugify(ea.value)}"]

  _generateUpdateAction: (enumAttribute, refEnum) =>
    switch refEnum.type.name
      when 'enum' then @_generateEnumUpdateAction(enumAttribute, refEnum)
      when 'lenum' then @_generateLenumUpdateAction(enumAttribute, refEnum)
      when 'set' then @_generateEnumSetUpdateActionByValueType(enumAttribute, refEnum)
      else throw err "Invalid enum type: #{refEnum.type.name}"

  _generateEnumSetUpdateActionByValueType: (enumAttribute, refEnum) =>
    if _.isArray(enumAttribute.value)
      @_generateMultipleValueEnumSetUpdateAction(enumAttribute, refEnum)
    else
      @_generateEnumSetUpdateAction(enumAttribute, refEnum)

  _generateMultipleValueEnumSetUpdateAction: (enumAttribute, refEnum) =>
    _.map enumAttribute.value, (attributeValue) =>
      ea =
        name: enumAttribute.name
        value: attributeValue
      @_generateEnumSetUpdateAction(ea, refEnum)

  _generateEnumSetUpdateAction: (enumAttribute, refEnum) =>
    switch refEnum.type.elementType.name
      when 'enum' then @_generateEnumUpdateAction(enumAttribute, refEnum)
      when 'lenum' then @_generateLenumUpdateAction(enumAttribute, refEnum)
      else throw err "Invalid set enum type: #{refEnum.type.elementType.name}"

  _generateEnumUpdateAction: (ea, refEnum) ->
    updateAction =
      action: 'addPlainEnumValue'
      attributeName: refEnum.name
      value:
        key: slugify(ea.value)
        label: ea.value
    updateAction

  _generateLenumUpdateAction: (ea, refEnum) ->
    updateAction =
      action: 'addLocalizedEnumValue'
      attributeName: refEnum.name
      value:
        key: slugify(ea.value)
        label:
          en: ea.value
          de: ea.value
          fr: ea.value
          it: ea.value
          es: ea.value
    updateAction


  _isEnumKeyPresent: (enumAttribute, refEnum) ->
    if refEnum.type.name is 'set'
      _.findWhere(refEnum.type.elementType.values, {key: slugify(enumAttribute.value)})
    else
      _.findWhere(refEnum.type.values, {key: slugify(enumAttribute.value)})

  _fetchEnumAttributesFromProduct: (product, resolvedProductType) =>
    enumAttributes = @_fetchEnumAttributesFromVariant(product.masterVariant, resolvedProductType)
    if product.variants and not _.isEmpty(product.variants)
      for variant in product.variants
        enumAttributes = enumAttributes.concat(@_fetchEnumAttributesFromVariant(variant, resolvedProductType))
    enumAttributes

  _fetchEnumAttributesFromVariant: (variant, productType) =>
    enums = []
    productTypeEnumNames = @_fetchEnumAttributeNamesOfProductType(productType)
    for attribute in variant.attributes
      if @_isEnumVariantAttribute(attribute, productTypeEnumNames)
        enums.push attribute
    enums

  _isEnumVariantAttribute: (attribute, productTypeEnums) ->
    attribute.name in productTypeEnums

  _fetchEnumAttributesOfProductType: (productType) =>
    @_extractEnumAttributesFromProductType(productType)

  _fetchEnumAttributeNamesOfProductType: (productType) =>
    if @_cache.productTypeEnumMap["#{productType.id}_names"]
      @_cache.productTypeEnumMap["#{productType.id}_names"]
    else
      enums = @_fetchEnumAttributesOfProductType(productType)
      names = _.pluck(enums, 'name')
      @_cache.productTypeEnumMap["#{productType.id}_names"] = names
      names

  _extractEnumAttributesFromProductType: (productType) =>
    _.filter(productType.attributes, @_enumLenumFilterPredicate)
      .concat(_.filter(productType.attributes, @_enumSetFilterPredicate))
      .concat(_.filter(productType.attributes, @_lenumSetFilterPredicate))

  _enumLenumFilterPredicate: (attribute) ->
    attribute.type.name is 'enum' or attribute.type.name is 'lenum'

  _enumSetFilterPredicate: (attribute) ->
    attribute.type.name is 'set' and attribute.type.elementType.name is 'enum'

  _lenumSetFilterPredicate: (attribute) ->
    attribute.type.name is 'set' and attribute.type.elementType.name is 'lenum'

module.exports = EnumValidator
