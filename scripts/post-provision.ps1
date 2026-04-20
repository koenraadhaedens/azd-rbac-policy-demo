<#
.SYNOPSIS
    Post-provision hook: uploads runbook content, publishes it, and links the schedule.

.DESCRIPTION
    Called by azd after infrastructure provisioning. Uses Az CLI automation extension
    to upload the PowerShell runbook script, publish it, and register the daily schedule.
#>

$ErrorActionPreference = 'Stop'

$automationAccountName = $env:AUTOMATION_ACCOUNT_NAME
$resourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME
$runbookName = 'Stop-VM-ChangeDisk'
$scheduleName = 'daily-1800-utc'
$scriptPath = Join-Path $PSScriptRoot 'Stop-VM-ChangeDisk.ps1'

Write-Host "Installing az automation extension..."
az extension add --name automation --upgrade --yes 2>$null

Write-Host "Uploading runbook content from '$scriptPath'..."
az automation runbook replace-content `
    --automation-account-name $automationAccountName `
    --resource-group $resourceGroupName `
    --name $runbookName `
    --content "@$scriptPath"

Write-Host "Publishing runbook '$runbookName'..."
az automation runbook publish `
    --automation-account-name $automationAccountName `
    --resource-group $resourceGroupName `
    --name $runbookName

Write-Host "Linking schedule '$scheduleName' to runbook '$runbookName'..."
$scheduleId = az automation schedule show `
    --automation-account-name $automationAccountName `
    --resource-group $resourceGroupName `
    --name $scheduleName `
    --query id -o tsv 2>$null

if ($scheduleId) {
    az rest --method PUT `
        --uri "https://management.azure.com/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$resourceGroupName/providers/Microsoft.Automation/automationAccounts/$automationAccountName/jobSchedules/$(New-Guid)?api-version=2023-11-01" `
        --body "{`"properties`":{`"schedule`":{`"name`":`"$scheduleName`"},`"runbook`":{`"name`":`"$runbookName`"}}}"
    Write-Host "Schedule linked to runbook."
}
else {
    Write-Warning "Schedule '$scheduleName' not found. Link manually after verifying schedule exists."
}

Write-Host "Post-provision complete."

azd env get-values > .env
$environmentName = $env:AZURE_ENV_NAME
$location = $env:AZURE_LOCATION
$machine  = "cloud-shell/1.0"
$commitHash = $env:GIT_COMMIT
# sending stats to table please comment out if you do not want this
# Your Azure Automation webhook URL
$webhookUrl = 'https://8116ebc5-9750-4a45-bb68-3623eef692f3.webhooks?token=mkbmnnnhgDsL20iey6qRj9Vc0ylCVg%2bpeZ1Yym7rsZs%3d'

# Build the payload as a PowerShell object
$deploymentData = @{
    Deployment      = $containerUrl
    location        = $location
    environmentName = $environmentName
    Machine         = $machine
    CommitHash      = $commitHash
    Timestamp       = (Get-Date).ToString("o")
}

# Convert to JSON (this becomes the actual webhook body)
$body = $deploymentData | ConvertTo-Json -Depth 5

# Send to Azure Automation as proper JSON
Invoke-RestMethod `
    -Uri $webhookUrl `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
    
Write-Output "Stats Tracked"
