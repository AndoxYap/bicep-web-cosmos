@description('Application Name')
@maxLength(30)
param applicationName string = 'to-do-app${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('App Service Plan\'s pricing tier. Details at https://azure.microsoft.com/en-us/pricing/details/app-service/')
param appServicePlanTier string = 'P1V2'

@minValue(1)
@maxValue(3)
@description('App Service Plan\'s instance count')
param appServicePlanInstances int = 1

@description('The URL for the GitHub repository that contains the project to deploy.')
param repositoryUrl string = 'https://github.com/Azure-Samples/cosmos-dotnet-core-todo-app.git'

@description('The branch of the GitHub repository to use.')
param branch string = 'main'

@description('Existing Azure DNS zone in target resource group')
param dnsZone string = '<YOUR CUSTOM DOMAIN i.e. "customdomain.com">'

@description('The Cosmos DB database name.')
param databaseName string = 'Tasks'

@description('The Cosmos DB container name.')
param containerName string = 'Items'

var cosmosAccountName = toLower(applicationName)
var websiteName = applicationName
var appServicePlanName = applicationName

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmosAccountName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
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

resource dnsTxt 'Microsoft.Network/dnsZones/TXT@2018-05-01' = {
  name: '${dnsZone}/asuid.${applicationName}'
  properties: {
    TTL: 3600
    TXTRecords: [
      {
        value: [
          '${appService.properties.customDomainVerificationId}'
        ]
      }
    ]
  }
}

resource dnsCname 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = {
  name: '${dnsZone}/${applicationName}'
  properties: {
    TTL: 3600
    CNAMERecord: {
      cname: '${appService.name}.azurewebsites.net'
    }
  }
}

// Enabling Managed certificate for a webapp requires 3 steps
// 1. Add custom domain to webapp with SSL in disabled state
// 2. Generate certificate for the domain
// 3. enable SSL

// The last step requires deploying again Microsoft.Web/sites/hostNameBindings - and ARM template forbids this in one deplyment, therefore we need to use modules to chain this.

resource webAppCustomHost 'Microsoft.Web/sites/hostNameBindings@2020-06-01' = {
  name: '${appService.name}/${applicationName}.${dnsZone}'
  dependsOn: [
    dnsTxt
    dnsCname
  ]
  properties: {
    hostNameType: 'Verified'
    sslState: 'Disabled'
    customHostNameDnsRecordType: 'CName'
    siteName: appService.name
  }
}

resource webAppCustomHostCertificate 'Microsoft.Web/certificates@2020-06-01' = {
  name: '${applicationName}.${dnsZone}'
  // name: dnsZone
  location: location
  dependsOn: [
    webAppCustomHost
  ]
  properties: any({
    serverFarmId: appServicePlan.id
    canonicalName: '${applicationName}.${dnsZone}'
  })
}

// we need to use a module to enable sni, as ARM forbids using resource with this same type-name combination twice in one deployment.
module webAppCustomHostEnable './sni-enable.bicep' = {
  name: '${deployment().name}-${applicationName}-sni-enable'
  params: {
    webAppName: appService.name
    webAppHostname: '${webAppCustomHostCertificate.name}'
    certificateThumbprint: webAppCustomHostCertificate.properties.thumbprint
  }
}
