#!/bin/sh
location='westus'
subscription='Non-Prod-Workloads'
resourceGroupName="ccm-lab-test"


az account set --subscription $subscription
az group create --name $resourceGroupName --location $location
az deployment group create \
    --mode Incremental \
    --resource-group $resourceGroupName \
    --template-file azuredeploy.json \
    --parameters @azuredeploy.parameters.json