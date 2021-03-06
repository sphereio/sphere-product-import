# Sphere Price Importer
Price Importer is used to import the prices for `existing` products of a project. It is a modified product importer which blacklists all update actions and whitelists price update actions.

### Configuration
 The constructor requires the following:
  * logger instance
  * sphere client (sphere-node-sdk) configuration
    * project credentials
    * user-agent
  * errorDir -> error directory path (absolute), default: `../errors`
  * errorLimit -> maximum number of errors to log, default: 30. If set to 0, logs all errors
  * preventRemoveActions -> When `true` it filters out all remove actions. Defaults to `false`
  * deleteOnEmpty -> When `true` it removes existing prices which have an empty string in `centAmount` in the import file. Defaults to `false`
  * publishingStrategy -> strategy for publishing the products with updates. Defaults to `false`
    * `always`: will always publish the products with updates.
    * `stagedAndPublishedOnly`: will publish the products only if the following conditions are met:
      * hasStagedChanges = true: if the product as staged changes other than the current updates. 
      * published = true: if the product was already published earlier.
    * `notStagedAndPublishedOnly`: will publish the products only if the following conditions are met:
      * hasStagedChanges = false: if the product has no other staged changes except the current ones.  
      * published = true: if the product was already published earlier.

#### Default configuration
 * The product sync instance is configured to blacklist all actions and whitelist `price` actions.

### Sample Input

      prices = [
            {
              sku: 'sku1'
              prices: [
                {
                  value:
                    centAmount: 9999
                    currencyCode: 'EUR'
                }
              ]
            }
            {
              sku: 'sku2'
              prices: [
                {
                  value:
                    centAmount: 666
                    currencyCode: 'JPY'
                  country: 'JP'
                }
              ]
            },
            {
              sku: '123'
              prices: [
                {
                  value:
                    currencyCode: 'EUR'
                    centAmount: 799
                  country: 'DE'
                  validFrom: '2000-01-01T00:00:00'
                  validTo: '2099-12-31T23:59:59'
                }
              ]
            }
          ]

### Sample Input for removing a specific price
Will match and remove price where `country == 'DE'` and `currencyCode == 'EUR'` 

      prices = [
            {
              sku: 'sku1'
              prices: [
                {
                  country: 'DE'
                  value:
                    centAmount: ''
                    currencyCode: 'EUR'
                }
              ]
            }
    