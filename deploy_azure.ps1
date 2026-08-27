# Azure Deployment Script
Write-Host "Creating Resource Group..."
az group create --name SipsaraMLGroup --location eastus

Write-Host "Creating Azure Container Registry..."
az acr create --resource-group SipsaraMLGroup --name sipsaramlacr2026 --sku Basic --admin-enabled true

Write-Host "Building Docker Image in ACR..."
az acr build --registry sipsaramlacr2026 --image sipsara-ml-backend:latest -f Dockerfile.azure .

Write-Host "Creating App Service Plan (B3)..."
az appservice plan create --name SipsaraMLPlan --resource-group SipsaraMLGroup --sku B3 --is-linux

Write-Host "Creating Web App for Containers..."
az webapp create --resource-group SipsaraMLGroup --plan SipsaraMLPlan --name sipsara-ml-backend-app --deployment-container-image-name sipsaramlacr2026.azurecr.io/sipsara-ml-backend:latest

Write-Host "Configuring App Settings..."
az webapp config appsettings set --resource-group SipsaraMLGroup --name sipsara-ml-backend-app --settings WEBSITES_PORT=8080

Write-Host "Deployment Initiated Successfully!"
