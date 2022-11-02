
targetScope = 'resourceGroup'

// @description('Name resource group')
// param resourceGroupName string

// // @description('Deployment variable from parameter file')
// // param deployment object

// @description('Environment to deploy')
// @allowed([
//   'dev'
//   'tst'
//   'uat'
//   'prd'
// ])
// param env string



// var rgEnvironments = json(loadTextContent('~/../Global/resourceGroup-environments.json'))

// var locationCodes = json(loadTextContent('~/../Global/location-codes.json'))

// var locationCode = locationCodes[location]

// var rgName = toUpper('RG-${locationCode}-${rgEnvironments[env]}-${resourceGroupName}')


@description('Application Name')
@maxLength(30)
param projectName string = ''

@description('Application Name')
@maxLength(30)
param applicationName string = '${projectName}-app${uniqueString(resourceGroup().id)}'

@description('The Azure region to deploy to.')
@metadata({
  strongType: 'location'
})
param location string = resourceGroup().location

@description('App Service Plan\'s pricing tier. Details at https://azure.microsoft.com/en-us/pricing/details/app-service/')
param appServicePlanTier string = 'F1'

@minValue(1)
@maxValue(3)
@description('App Service Plan\'s instance count')
param appServicePlanInstances int = 1

@description('The URL for the GitHub repository that contains the project to deploy.')
param repositoryUrl string = 'https://github.com/AndoxADX/net6-cc'

@description('The branch of the GitHub repository to use.')
param branch string = 'main'

@description('The Cosmos DB database name.')
param databaseName string = 'Tasks'

@description('The Cosmos DB container name.')
param containerName string = 'Items'

var cosmosAccountName = toLower(applicationName)
var websiteName = applicationName
var appServicePlanName = applicationName


resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' existing =  {
  name: cosmosAccountName
  scope: resourceGroup()
  // kind: 'GlobalDocumentDB'
  // location: location
  // properties: {
  //   consistencyPolicy: {
  //     defaultConsistencyLevel: 'Session'
  //   }
  //   locations: [
  //     {
  //       locationName: location
  //       failoverPriority: 0
  //       isZoneRedundant: false
  //     }
  //   ]
  //   databaseAccountOfferType: 'Standard'
  // }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanTier
    capacity: appServicePlanInstances
  }
  kind: 'linux'
}

resource appService 'Microsoft.Web/sites@2021-01-01' = {
  name: websiteName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      http20Enabled: true

      appSettings: [
        {
          name: 'CosmosDb:Account'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'CosmosDb:Key'
          value: listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey
        }
        {
          name: 'CosmosDb:DatabaseName'
          value: databaseName
        }
        {
          name: 'CosmosDb:ContainerName'
          value: containerName
        }
      ]
    }
  }
}

resource srcControls 'Microsoft.Web/sites/sourcecontrols@2021-01-01' = {
  name: '${appService.name}/web'
  properties: {
    repoUrl: repositoryUrl
    branch: branch
    isManualIntegration: true
  }
}
