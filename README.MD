# Retrieving cost data from Azure for offline analysis with Azure Data Factory


## About
An example of how to use Azure Data Factory to retrieve usage data from the [Azure Management API](https://docs.microsoft.com/en-us/rest/api/consumption/usagedetails/list) and store the results in [Azure Data Lake](https://docs.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction).  

## Deployment

A [Service Principal](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#create-and-authenticate-your-service-principal) with [Enrollment Reader](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#permissions-that-can-be-assigned-to-the-spn) permissions assigned at the [Enrollment level](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn) is required before deploying this example.

### Create the Service Principal using the Azure Portal
1. [Create and authenticate your service principal](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#create-and-authenticate-your-service-principal)
2. [Assign enrollment account role permission to the SPN](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/assign-roles-azure-service-principals#assign-enrollment-account-role-permission-to-the-spn)

Take note of the service principal's tenant ID, application ID and secret as they're required for the next step.
The Enrollment ID variable can be obtained from from *Cost Management and Billing* in the [Azure Portal](https://portal.azure.com) or the [EA Portal](https://ea.azure.com)

### Create the Service Principal using Powershell and the Azure CLI
```powershell
# Parameters
$enrollmentNumber='123456789'
$servicePrincipalName='svc-ea-reader'

# Variables
$uri='https://management.azure.com/providers/Microsoft.Billing/billingAccounts/{0}/billingRoleAssignments/c67bfb76-2e8d-4728-bf32-f9bdd54c5df2?api-version=2019-10-01-preview' -f $enrollmentNumber
$fileName=".\$servicePrincipalName.txt"

# Main
if ($null -eq (get-item $fileName -ErrorAction SilentlyContinue))
{
    az ad sp create-for-rbac --skip-assignment --name $servicePrincipalName >> $fileName
}

$servicePrincipal = (Get-Content $fileName | ConvertFrom-Json)
$objectId = (az ad sp show --id $servicePrincipal.appId --query objectId -o tsv)

$body='{\"properties\": {\"principalId\": \"<principalId>\",\"principalTenantId\": \"<principalTenantId>\",\"roleDefinitionId\": \"/providers/Microsoft.Billing/billingAccounts/<enrollmentId>/billingRoleDefinitions/24f8edb6-1668-4659-b5e2-40bb5f3a7d7e\"}}'

$body = $body.Replace("<principalId>", $objectId)
$body = $body.Replace("<principalTenantId>", $servicePrincipal.tenant)
$body = $body.Replace("<enrollmentId>", $enrollmentNumber)

az rest --method put --uri $uri --body $body --debug
```

### Paremeters

Parameter                   | Default Value | Notes
--------------------------- | ------------- | -------------------------
Aad Resource Id             | [parameters('managementApiUri')] | Same value as Management API URI
Blob Container Name         | [concat('ccm', uniqueString(resourceGroup().id, resourceGroup().location))] | 
Data Factory Name           | [concat('datafactory', uniqueString(resourceGroup().id, resourceGroup().location))] | 
Enrollment Id               | **Required**| Obtained from Cost Management and Billing in the Azure Portal or the EA Portal
Keyvault Name               | [concat('keyvault', uniqueString(resourceGroup().id, resourceGroup().location))] | 
Management Api Uri          | https://management.azure.com | Modify to support different Azure clouds
Service Principal Id        | **Required** | The Application ID of the service principal (not the object id)
Service Principal Secret    | **Required** | The password for the service principal obtained during creation
Service Principal Tenant Id | **Required** | The ID of Azure AD Tenant containing the service principal
Storage Account Name        | [concat('storage', uniqueString(resourceGroup().id, resourceGroup().location))] | 


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
## Post Deployment

### Initialize the dataset
Initializing the dataset is a two-step process.
Initialize the dataset by executing the "GetUsageRange" pipeline and providing the desired date range.  
- UsageStartDate - Set to the first date to download - for example the beginning of current FY or quarter.
- UsageEndDate - Set to the current date.

![Initialize](https://github.com/MSBrett/ccm_datafactory/raw/master/resources/Initialize.jpg)

![SetDates](https://github.com/MSBrett/ccm_datafactory/raw/master/resources/SetDates.jpg)

### Create a daily Schedule
Once the dataset is initialized create a daily schedule for the GetUsageCurrent pipeline and **publish the changes.**

![StartSchedule](https://github.com/MSBrett/ccm_datafactory/raw/master/resources/StartSchedule.jpg)

## Importing the data into Power BI

To import the data into Power BI first create a function to decompress each file in Power BI

***fnUnpackData***
```script
(zipData) =>
let
        Source = Binary.Decompress(zipData, Compression.GZip),
        #"Imported" = Csv.Document(Source,[Delimiter=",", Columns=50, Encoding=1252, QuoteStyle=QuoteStyle.None]),
        #"Promoted Headers" = Table.PromoteHeaders(#"Imported", [PromoteAllScalars=true])
in
        #"Promoted Headers"
```

Then create data tables with the following definitions and correct data lake URI

***Amortized Costs***
```script
let
    Source = AzureStorage.DataLake(https://DataLakeUri),
    Filter = Table.SelectRows(Source, each [Name] = "amortizedcost.csv.gz"),
    Unpack = Table.AddColumn(Filter, "Custom", each fnUnpackData([Content])),
    #"Removed Columns" = Table.RemoveColumns(Unpack,{"Content", "Name", "Extension", "Date accessed", "Date modified", "Date created", "Attributes", "Folder Path"}),
    #"Expand CSV" = Table.ExpandTableColumn(#"Removed Columns", "Custom", {"BillingAccountId", "BillingAccountName", "BillingPeriodStartDate", "BillingPeriodEndDate", "BillingProfileId", "BillingProfileName", "AccountOwnerId", "AccountName", "SubscriptionId", "SubscriptionName", "Date", "Product", "PartNumber", "MeterId", "ServiceFamily", "MeterCategory", "MeterSubCategory", "MeterRegion", "MeterName", "Quantity", "EffectivePrice", "Cost", "UnitPrice", "BillingCurrency", "ResourceLocation", "AvailabilityZone", "ConsumedService", "ResourceId", "ResourceName", "ServiceInfo1", "ServiceInfo2", "AdditionalInfo", "Tags", "InvoiceSectionId", "InvoiceSection", "CostCenter", "UnitOfMeasure", "ResourceGroup", "ReservationId", "ReservationName", "ProductOrderId", "ProductOrderName", "OfferId", "IsAzureCreditEligible", "Term", "PublisherName", "PlanName", "ChargeType", "Frequency", "PublisherType"}, {"BillingAccountId", "BillingAccountName", "BillingPeriodStartDate", "BillingPeriodEndDate", "BillingProfileId", "BillingProfileName", "AccountOwnerId", "AccountName", "SubscriptionId", "SubscriptionName", "Date", "Product", "PartNumber", "MeterId", "ServiceFamily", "MeterCategory", "MeterSubCategory", "MeterRegion", "MeterName", "Quantity", "EffectivePrice", "Cost", "UnitPrice", "BillingCurrency", "ResourceLocation", "AvailabilityZone", "ConsumedService", "ResourceId", "ResourceName", "ServiceInfo1", "ServiceInfo2", "AdditionalInfo", "Tags", "InvoiceSectionId", "InvoiceSection", "CostCenter", "UnitOfMeasure", "ResourceGroup", "ReservationId", "ReservationName", "ProductOrderId", "ProductOrderName", "OfferId", "IsAzureCreditEligible", "Term", "PublisherName", "PlanName", "ChargeType", "Frequency", "PublisherType"}),
    #"Filtered Rows" = Table.SelectRows(#"Expand CSV", each ([ReservationName] <> "")),
    #"Changed Type" = Table.TransformColumnTypes(#"Filtered Rows",{{"BillingAccountId", Int64.Type}, {"BillingAccountName", type text}, {"BillingPeriodStartDate", type date}, {"BillingPeriodEndDate", type date}, {"BillingProfileId", Int64.Type}, {"BillingProfileName", type text}, {"AccountOwnerId", type text}, {"AccountName", type text}, {"SubscriptionId", type text}, {"SubscriptionName", type text}, {"Date", type date}, {"Product", type text}, {"PartNumber", type text}, {"MeterId", type text}, {"ServiceFamily", type text}, {"MeterCategory", type text}, {"MeterSubCategory", type text}, {"MeterRegion", type text}, {"MeterName", type text}, {"Quantity", type number}, {"EffectivePrice", type number}, {"Cost", type number}, {"UnitPrice", type number}, {"BillingCurrency", type text}, {"ResourceLocation", type text}, {"AvailabilityZone", type any}, {"ConsumedService", type text}, {"ResourceId", type text}, {"ResourceName", type text}, {"ServiceInfo1", type any}, {"ServiceInfo2", type text}, {"AdditionalInfo", type text}, {"Tags", type text}, {"InvoiceSectionId", type any}, {"InvoiceSection", type text}, {"CostCenter", type text}, {"UnitOfMeasure", type text}, {"ResourceGroup", type text}, {"ReservationId", type text}, {"ReservationName", type text}, {"ProductOrderId", type text}, {"ProductOrderName", type text}, {"OfferId", type text}, {"IsAzureCreditEligible", type logical}, {"Term", Int64.Type}, {"PublisherName", type any}, {"PlanName", type any}, {"ChargeType", type text}, {"Frequency", type text}, {"PublisherType", type text}})
in
    #"Changed Type"
```
***Actual Costs***
```script
let
    Source = AzureStorage.DataLake(https://DataLakeUri),
    Filter = Table.SelectRows(Source, each [Name] = "actualcost.csv.gz"),
    Unpack = Table.AddColumn(Filter, "Custom", each fnUnpackData([Content])),
    #"Removed Columns" = Table.RemoveColumns(Unpack,{"Content", "Name", "Extension", "Date accessed", "Date modified", "Date created", "Attributes", "Folder Path"}),
    #"Expand CSV" = Table.ExpandTableColumn(#"Removed Columns", "Custom", {"BillingAccountId", "BillingAccountName", "BillingPeriodStartDate", "BillingPeriodEndDate", "BillingProfileId", "BillingProfileName", "AccountOwnerId", "AccountName", "SubscriptionId", "SubscriptionName", "Date", "Product", "PartNumber", "MeterId", "ServiceFamily", "MeterCategory", "MeterSubCategory", "MeterRegion", "MeterName", "Quantity", "EffectivePrice", "Cost", "UnitPrice", "BillingCurrency", "ResourceLocation", "AvailabilityZone", "ConsumedService", "ResourceId", "ResourceName", "ServiceInfo1", "ServiceInfo2", "AdditionalInfo", "Tags", "InvoiceSectionId", "InvoiceSection", "CostCenter", "UnitOfMeasure", "ResourceGroup", "ReservationId", "ReservationName", "ProductOrderId", "ProductOrderName", "OfferId", "IsAzureCreditEligible", "Term", "PublisherName", "PlanName", "ChargeType", "Frequency", "PublisherType"}, {"BillingAccountId", "BillingAccountName", "BillingPeriodStartDate", "BillingPeriodEndDate", "BillingProfileId", "BillingProfileName", "AccountOwnerId", "AccountName", "SubscriptionId", "SubscriptionName", "Date", "Product", "PartNumber", "MeterId", "ServiceFamily", "MeterCategory", "MeterSubCategory", "MeterRegion", "MeterName", "Quantity", "EffectivePrice", "Cost", "UnitPrice", "BillingCurrency", "ResourceLocation", "AvailabilityZone", "ConsumedService", "ResourceId", "ResourceName", "ServiceInfo1", "ServiceInfo2", "AdditionalInfo", "Tags", "InvoiceSectionId", "InvoiceSection", "CostCenter", "UnitOfMeasure", "ResourceGroup", "ReservationId", "ReservationName", "ProductOrderId", "ProductOrderName", "OfferId", "IsAzureCreditEligible", "Term", "PublisherName", "PlanName", "ChargeType", "Frequency", "PublisherType"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Expand CSV",{{"BillingAccountId", Int64.Type}, {"BillingAccountName", type text}, {"BillingPeriodStartDate", type date}, {"BillingPeriodEndDate", type date}, {"BillingProfileId", Int64.Type}, {"BillingProfileName", type text}, {"AccountOwnerId", type text}, {"AccountName", type text}, {"SubscriptionId", type text}, {"SubscriptionName", type text}, {"Date", type date}, {"Product", type text}, {"PartNumber", type text}, {"MeterId", type text}, {"ServiceFamily", type text}, {"MeterCategory", type text}, {"MeterSubCategory", type text}, {"MeterRegion", type text}, {"MeterName", type text}, {"Quantity", type number}, {"EffectivePrice", type number}, {"Cost", type number}, {"UnitPrice", type number}, {"BillingCurrency", type text}, {"ResourceLocation", type text}, {"AvailabilityZone", type any}, {"ConsumedService", type text}, {"ResourceId", type text}, {"ResourceName", type text}, {"ServiceInfo1", type any}, {"ServiceInfo2", type text}, {"AdditionalInfo", type text}, {"Tags", type text}, {"InvoiceSectionId", type any}, {"InvoiceSection", type text}, {"CostCenter", type text}, {"UnitOfMeasure", type text}, {"ResourceGroup", type text}, {"ReservationId", type text}, {"ReservationName", type text}, {"ProductOrderId", type text}, {"ProductOrderName", type text}, {"OfferId", type text}, {"IsAzureCreditEligible", type logical}, {"Term", Int64.Type}, {"PublisherName", type any}, {"PlanName", type any}, {"ChargeType", type text}, {"Frequency", type text}, {"PublisherType", type text}})
in
    #"Changed Type"
```