// @description('Cosmos DB account name')
// param accountName string = 'cosmos-${uniqueString(resourceGroup().id)}'
@description('Cosmos DB account name')
param name string

@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location

@description('The name for the SQL API database')
param dbName string

@description('Names of containers to create')
param containers array

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(name)
  location: location
  properties: {
    enableFreeTier: true
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
      }
    ]
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  parent: cosmosDb
  name: dbName
  properties: {
    resource: {
      id: dbName
    }
    options: {
      throughput: 1000
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = [for container in containers:{
  parent: database
  name: container.name
  properties: { 
    resource: {
      id: container.name
      partitionKey: {
        paths: [
         '/${container.partitionKey}' 
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/_etag/?'
          }
        ]
      }
    }
  }
  dependsOn:[
    cosmosDb
  ]
}]
