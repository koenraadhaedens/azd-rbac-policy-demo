@description('Azure region.')
param location string

@description('Project name for resource naming.')
param projectName string

@description('Environment name.')
param environmentName string

@description('Resource tags.')
param tags object

@description('Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Name of the VM to manage.')
param vmName string

@description('Current UTC time for schedule start. Defaults via utcNow().')
param currentUtcTime string

var automationAccountName = 'aa-${projectName}-${environmentName}'

resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    publicNetworkAccess: true
  }
}

resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automationAccount
  name: 'Stop-VM-ChangeDisk'
  location: location
  tags: tags
  properties: {
    runbookType: 'PowerShell72'
    logProgress: true
    logVerbose: true
    description: 'Stops/deallocates VM and downgrades OS disk from Premium_LRS to Standard_LRS for cost savings'
  }
}

resource schedule 'Microsoft.Automation/automationAccounts/schedules@2023-11-01' = {
  parent: automationAccount
  name: 'daily-1800-utc'
  properties: {
    frequency: 'Day'
    interval: 1
    startTime: dateTimeAdd(currentUtcTime, 'P1D')
    timeZone: 'UTC'
    description: 'Daily schedule at 18:00 UTC for cost optimization'
  }
}

resource rgVariable 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automationAccount
  name: 'ResourceGroupName'
  properties: {
    value: '"${resourceGroup().name}"'
    isEncrypted: false
    description: 'Resource group containing the target VM'
  }
}

resource vmVariable 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automationAccount
  name: 'VmName'
  properties: {
    value: '"${vmName}"'
    isEncrypted: false
    description: 'Name of the target VM'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${automationAccountName}'
  scope: automationAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output automationAccountName string = automationAccount.name
output principalId string = automationAccount.identity.principalId
output resourceId string = automationAccount.id
output resourceName string = automationAccount.name
