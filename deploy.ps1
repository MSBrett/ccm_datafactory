param(
    [string]$location='westus',
    [string]$subscription='Non-Prod-Workloads',
    [string]$resourceGroupName="ccm-lab-test",
    [string]$paramFile="./azuredeploy.parameters.json"
)

az account set --subscription $subscription
az group create --name $resourceGroupName --location $location
az deployment group create `
    --mode Incremental `
    --resource-group $resourceGroupName `
    --template-file azuredeploy.json `
    --parameters $paramFile