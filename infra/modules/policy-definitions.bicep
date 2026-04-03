targetScope = 'subscription'

// Policy 1: Require CostCenter and Owner tags on all resources
resource requireTagsPolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'require-costcenter-owner-tags'
  properties: {
    displayName: 'Require CostCenter and Owner tags on resources'
    description: 'Denies creation of resources missing CostCenter or Owner tags'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Tags'
    }
    policyRule: {
      if: {
        anyOf: [
          {
            field: 'tags[\'CostCenter\']'
            exists: 'false'
          }
          {
            field: 'tags[\'Owner\']'
            exists: 'false'
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

// Policy 2: Audit VMs without Microsoft Defender for Endpoint extension
resource auditMdePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'audit-mde-on-vms'
  properties: {
    displayName: 'Audit Microsoft Defender for Endpoint on VMs'
    description: 'Audits virtual machines that do not have the MDE extension installed'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Security'
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType'
            equals: 'Windows'
          }
        ]
      }
      then: {
        effect: 'auditIfNotExists'
        details: {
          type: 'Microsoft.Compute/virtualMachines/extensions'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'MDE.Windows'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Microsoft.Azure.AzureDefenderForServers'
              }
            ]
          }
        }
      }
    }
  }
}

// Policy 3: deployIfNotExists to auto-install MDE on Windows VMs
resource deployMdePolicy 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'deploy-mde-on-windows-vms'
  properties: {
    displayName: 'Deploy Microsoft Defender for Endpoint on Windows VMs'
    description: 'Automatically installs MDE extension on Windows VMs if missing'
    policyType: 'Custom'
    mode: 'Indexed'
    metadata: {
      category: 'Security'
    }
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Compute/virtualMachines'
          }
          {
            field: 'Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType'
            equals: 'Windows'
          }
        ]
      }
      then: {
        effect: 'deployIfNotExists'
        details: {
          type: 'Microsoft.Compute/virtualMachines/extensions'
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
          ]
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/type'
                equals: 'MDE.Windows'
              }
              {
                field: 'Microsoft.Compute/virtualMachines/extensions/publisher'
                equals: 'Microsoft.Azure.AzureDefenderForServers'
              }
            ]
          }
          deployment: {
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
                contentVersion: '1.0.0.0'
                parameters: {
                  vmName: {
                    type: 'string'
                  }
                  location: {
                    type: 'string'
                  }
                }
                resources: [
                  {
                    type: 'Microsoft.Compute/virtualMachines/extensions'
                    apiVersion: '2024-03-01'
                    name: '[concat(parameters(\'vmName\'), \'/MDE.Windows\')]'
                    location: '[parameters(\'location\')]'
                    properties: {
                      publisher: 'Microsoft.Azure.AzureDefenderForServers'
                      type: 'MDE.Windows'
                      typeHandlerVersion: '1.0'
                      autoUpgradeMinorVersion: true
                      settings: {
                        azureResourceId: '[resourceId(\'Microsoft.Compute/virtualMachines\', parameters(\'vmName\'))]'
                      }
                    }
                  }
                ]
              }
              parameters: {
                vmName: {
                  value: '[field(\'name\')]'
                }
                location: {
                  value: '[field(\'location\')]'
                }
              }
            }
          }
        }
      }
    }
  }
}

output requireTagsPolicyId string = requireTagsPolicy.id
output auditMdePolicyId string = auditMdePolicy.id
output deployMdePolicyId string = deployMdePolicy.id
