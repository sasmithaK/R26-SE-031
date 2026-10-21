# Azure Deployment Script for ML Gateway Backend
$ErrorActionPreference = "Stop"

$SUBSCRIPTION_ID = "3084fb12-dde0-4869-9d79-1efd494962e4"
$RESOURCE_GROUP = "SipsaraMLGroup"
$LOCATION = "eastasia"
$ACR_NAME = "sipsaramlacr26"
$PLAN_NAME = "SipsaraMLPlan"
$APP_NAME = "sipsara-ml-backend-v2"
$SKU = "B2"

# Runtime credentials must be supplied by the operator and are never stored in
# this repository. Existing Azure App Service settings can also be managed in
# Portal > App Service > Environment variables.
$requiredSecrets = @("MONGODB_URL", "JWT_SECRET_KEY")
foreach ($secretName in $requiredSecrets) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($secretName))) {
        throw "Set the $secretName environment variable before running this script."
    }
}

Write-Host "Setting active Azure subscription to $SUBSCRIPTION_ID..."
az account set --subscription $SUBSCRIPTION_ID

Write-Host "Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create --name $RESOURCE_GROUP --location $LOCATION

Write-Host "Creating Azure Container Registry: $ACR_NAME..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

Write-Host "Building Docker Image in ACR (this builds directly in Azure)..."
az acr build --registry $ACR_NAME --image sipsara-ml-backend:latest -f Dockerfile.azure .

Write-Host "Fetching ACR admin credentials..."
$acrCreds = az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP -o json | ConvertFrom-Json
$acrUser = $acrCreds.username
$acrPass = $acrCreds.passwords[0].value

Write-Host "Creating Linux App Service Plan ($SKU)..."
az appservice plan create --name $PLAN_NAME --resource-group $RESOURCE_GROUP --sku $SKU --is-linux

Write-Host "Creating Web App for Containers: $APP_NAME..."
az webapp create --resource-group $RESOURCE_GROUP --plan $PLAN_NAME --name $APP_NAME `
    --container-image-name "$($ACR_NAME).azurecr.io/sipsara-ml-backend:latest" `
    --docker-registry-server-user $acrUser `
    --docker-registry-server-password $acrPass

Write-Host "Configuring App Settings and Environment Variables..."
$appSettings = @(
    "WEBSITES_PORT=8080",
    "WEBSITES_CONTAINER_START_TIME_LIMIT=600",
    "MONGODB_URL=$env:MONGODB_URL",
    "MONGODB_DB_NAME=r26_se_031",
    "JWT_SECRET_KEY=$env:JWT_SECRET_KEY",
    "PRELOAD_STT=true",
    "C4_POLICY_MODE=shadow"
)

# Optional: only needed when testing generated C2 voice prompts.
if (-not [string]::IsNullOrWhiteSpace($env:GEMINI_API_KEY)) {
    $appSettings += "GEMINI_API_KEY=$env:GEMINI_API_KEY"
}

az webapp config appsettings set --resource-group $RESOURCE_GROUP --name $APP_NAME --settings $appSettings

Write-Host "Deployment completed successfully! Web App URL: https://$APP_NAME.azurewebsites.net"
