## resource group create + deploy 
az group create --name bicep-acr-rg --location centralus

az deployment group create --resource-group bicep-acr-rg --template-file  ACR-basic\deploy.bicep 
<!-- --parameters v3\deployment\parameters.json -->

az deployment group what-if --resource-group bicep-acr-rg --template-file ACR-basic\deploy.bicep 
<!-- --parameters v3\deployment\parameters.json -->
