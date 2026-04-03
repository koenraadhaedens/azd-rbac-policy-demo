@description('Azure region.')
param location string

@description('Resource ID of the require-tags policy definition.')
param requireTagsPolicyId string

@description('Resource ID of the audit-MDE policy definition.')
param auditMdePolicyId string

@description('Resource ID of the deploy-MDE policy definition.')
param deployMdePolicyId string

// Assignment 1: Require CostCenter + Owner tags
resource tagPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'assign-require-tags'
  properties: {
    displayName: 'Require CostCenter and Owner tags'
    description: 'Denies resource creation without CostCenter and Owner tags in this resource group'
    policyDefinitionId: requireTagsPolicyId
    enforcementMode: 'Default'
  }
}

// Assignment 2: Audit MDE on VMs
resource auditMdePolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'assign-audit-mde'
  properties: {
    displayName: 'Audit MDE on Virtual Machines'
    description: 'Audits VMs without Microsoft Defender for Endpoint extension'
    policyDefinitionId: auditMdePolicyId
    enforcementMode: 'Default'
  }
}

// Assignment 3: Deploy MDE on Windows VMs (needs managed identity for remediation)
resource deployMdePolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'assign-deploy-mde'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Deploy MDE on Windows VMs'
    description: 'Auto-installs MDE extension on non-compliant Windows VMs'
    policyDefinitionId: deployMdePolicyId
    enforcementMode: 'Default'
  }
}

// The DINE policy MI needs Virtual Machine Contributor to install extensions
var vmContributorRoleId = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

resource policyMiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deployMdePolicyAssignment.id, vmContributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmContributorRoleId)
    principalId: deployMdePolicyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output tagPolicyAssignmentId string = tagPolicyAssignment.id
output auditMdePolicyAssignmentId string = auditMdePolicyAssignment.id
output deployMdePolicyAssignmentId string = deployMdePolicyAssignment.id
