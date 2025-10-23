// ================================================================
// Network Module: Zero Trust Network Architecture
// ================================================================
// Creates VNet, subnets, NSGs, and optional Azure Bastion
// Implements zero trust principles with least privilege access

// ================================================================
// PARAMETERS
// ================================================================

@description('The Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('Network configuration object')
param networkConfig object

@description('Deploy Azure Bastion for secure access')
param deployBastion bool

// ================================================================
// NETWORK SECURITY GROUP
// ================================================================

resource vmssNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: networkConfig.nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1001
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowX11VNC'
        properties: {
          priority: 1002
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: ['5900-5999', '6000-6010']
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowRDP'
        properties: {
          priority: 1003
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          access: 'Deny'
          direction: 'Inbound'
          destinationPortRange: '*'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ================================================================
// VIRTUAL NETWORK
// ================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: networkConfig.vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [networkConfig.vnetAddressPrefix]
    }
    subnets: [
      {
        name: networkConfig.vmssSubnetName
        properties: {
          addressPrefix: networkConfig.vmssSubnetPrefix
          networkSecurityGroup: {
            id: vmssNetworkSecurityGroup.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      // Conditionally add Bastion subnet
      ...(deployBastion ? [{
        name: networkConfig.bastionSubnetName
        properties: {
          addressPrefix: networkConfig.bastionSubnetPrefix
        }
      }] : [])
    ]
  }
}

// ================================================================
// BASTION PUBLIC IP
// ================================================================

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (deployBastion) {
  name: '${networkConfig.bastionName}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ================================================================
// AZURE BASTION
// ================================================================

resource azureBastion 'Microsoft.Network/bastionHosts@2023-09-01' = if (deployBastion) {
  name: networkConfig.bastionName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    enableIpConnect: true
    ipConfigurations: [
      {
        name: 'bastionHostIpConfiguration'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/${networkConfig.bastionSubnetName}'
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

// ================================================================
// OUTPUTS
// ================================================================

output virtualNetworkId string = virtualNetwork.id
output vmssSubnetId string = '${virtualNetwork.id}/subnets/${networkConfig.vmssSubnetName}'
output bastionName string = deployBastion ? azureBastion.name : ''
output networkSecurityGroupId string = vmssNetworkSecurityGroup.id
output vnetName string = virtualNetwork.name

// Network Configuration Summary
output networkSummary object = {
  vnetName: virtualNetwork.name
  vnetAddressSpace: networkConfig.vnetAddressPrefix
  vmssSubnet: networkConfig.vmssSubnetPrefix
  bastionSubnet: deployBastion ? networkConfig.bastionSubnetPrefix : 'Not deployed'
  securityGroups: 'Restrictive NSG with least privilege access'
  bastionEnabled: deployBastion
}