#!/bin/sh
location='westus'
subscription='workload'
resourceGroupName="ccm-lab"


az account set --subscription $subscription
az group create --name $resourceGroupName --location $location
az deployment group create \
    --mode Incremental \
    --resource-group $resourceGroupName \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json