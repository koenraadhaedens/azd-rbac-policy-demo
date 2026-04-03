using './main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')
param adminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD', 'D3m0P@ssw0rd2026!')
