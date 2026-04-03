@description('Azure region.')
param location string

@description('Project name for resource naming.')
param projectName string

@description('Environment name.')
param environmentName string

@description('Resource tags.')
param tags object

var vnetName = 'vnet-${projectName}-${environmentName}'
var subnetName = 'snet-vm-${environmentName}'
var nsgName = 'nsg-vm-${environmentName}'
var pipName = 'pip-vm-${environmentName}'

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

output subnetId string = vnet.properties.subnets[0].id
output publicIpId string = publicIp.id
output nsgId string = nsg.id
output vnetName string = vnet.name
output resourceId string = vnet.id
output resourceName string = vnet.name
