# Automating Azure cost data retrieval for offline analysis with Azure Data Factory

## About
An example of how to use Azure Data Factory to retrieve usage data from the [Azure Management API](https://docs.microsoft.com/en-us/rest/api/consumption/usagedetails/list) and store the results in [Azure Data Lake](https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction).  A [Service Principal](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#create-and-authenticate-your-service-principal) with [Enrollment Reader](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#permissions-that-can-be-assigned-to-the-spn) permissions assigned at the [Enrollment level](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn) is required before deploying this example.


### Deploy via the Azure Portal

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMSBrett%2Fccm_datafactory%2Fmaster%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FMSBrett%2Fccm_datafactory%2Fmaster%2Fazuredeploy.json)

### Deploy using the Azure CLI

```bash
#!/bin/bash
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
```
### Post Deployment

#### Initialize the dataset
Initialize the dataset by executing the "GetUsageRange" pipeline and providing the desired date range.  
- UsageStartDate - Set to the first date to download - for example the beginning of current FY or quarter.
- UsageEndDate - Set to the current date.

![Initialize](https://github.com/MSBrett/ccm_datafactory/raw/master/resources/Initialize.jpg)

![SetDates](https://github.com/MSBrett/ccm_datafactory/raw/master/resources/SetDates.jpg)

#### Start the daily Schedule
Once the dataset is initialized enable the daily schedule and **publish the changes.**

![StartSchedule](https://github.com/MSBrett/ccm_datafactory/raw/master/resources/StartSchedule.jpg)