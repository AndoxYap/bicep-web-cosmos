# deploy cosmosdb standard provision
### refer: https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/manage-with-bicep
 az deployment group create --resource-group Test_Azure --template-file cosmosdb-free/main.bicep
