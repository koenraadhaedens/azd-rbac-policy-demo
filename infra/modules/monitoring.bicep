@description('Azure region.')
param location string

@description('Project name for resource naming.')
param projectName string

@description('Environment name.')
param environmentName string

@description('Resource tags.')
param tags object

var workspaceName = 'log-${projectName}-${environmentName}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
output resourceId string = logAnalytics.id
output resourceName string = logAnalytics.name
