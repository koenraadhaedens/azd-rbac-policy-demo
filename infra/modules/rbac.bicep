@description('Principal ID of the Automation Account managed identity.')
param automationAccountPrincipalId string

// Custom RBAC role: only VM stop/deallocate + disk SKU change
resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, 'vm-cost-optimizer')
  properties: {
    roleName: 'VM Cost Optimizer (${resourceGroup().name})'
    description: 'Least-privilege role: stop/deallocate VM and update disk SKU only'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/powerOff/action'
          'Microsoft.Compute/virtualMachines/deallocate/action'
          'Microsoft.Compute/disks/read'
          'Microsoft.Compute/disks/write'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      resourceGroup().id
    ]
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, customRole.id, automationAccountPrincipalId)
  properties: {
    roleDefinitionId: customRole.id
    principalId: automationAccountPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output customRoleId string = customRole.id
output customRoleName string = customRole.properties.roleName
output roleAssignmentId string = roleAssignment.id
