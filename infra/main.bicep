targetScope = 'subscription'

@description('Azure region for all resources.')
param location string

@description('azd environment name.')
param environmentName string

@description('Principal ID of the deploying user. azd populates this automatically.')
param principalId string = ''

@secure()
@description('Admin password for the Windows VM.')
param adminPassword string

@description('UTC timestamp for schedule calculation.')
param currentUtcTime string = utcNow('yyyy-MM-ddT18:00:00Z')

var projectName = 'rbac-policy-cost-opt'
var resourceGroupName = 'rg-${projectName}-${environmentName}'
var vmName = 'vm-demo-${environmentName}'

var tags = {
  Environment: environmentName
  ManagedBy: 'Bicep'
  Project: projectName
  SecurityControl: 'Ignore'
  CostCenter: 'Demo'
  Owner: 'AzureDemo'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
  }
}

module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
  }
}

module vm 'modules/vm.bicep' = {
  name: 'vm'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
    vmName: vmName
    subnetId: network.outputs.subnetId
    publicIpId: network.outputs.publicIpId
    adminUsername: 'azuredemo'
    adminPassword: adminPassword
  }
}

module automation 'modules/automation.bicep' = {
  name: 'automation'
  scope: rg
  params: {
    location: location
    projectName: projectName
    environmentName: environmentName
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    vmName: vmName
    currentUtcTime: currentUtcTime
  }
}

module rbac 'modules/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    automationAccountPrincipalId: automation.outputs.principalId
  }
}

module policyDefinitions 'modules/policy-definitions.bicep' = {
  name: 'policy-definitions'
}

module policyAssignments 'modules/policy-assignments.bicep' = {
  name: 'policy-assignments'
  scope: rg
  params: {
    location: location
    requireTagsPolicyId: policyDefinitions.outputs.requireTagsPolicyId
    auditMdePolicyId: policyDefinitions.outputs.auditMdePolicyId
    deployMdePolicyId: policyDefinitions.outputs.deployMdePolicyId
  }
  dependsOn: [vm, automation, network, monitoring]
}

output AZURE_RESOURCE_GROUP_NAME string = rg.name
output AUTOMATION_ACCOUNT_NAME string = automation.outputs.automationAccountName
output VM_NAME string = vm.outputs.vmName
output LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.logAnalyticsWorkspaceName
