// Azure Virtual Network Quickstart - Main Template
// Based on: https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network?tabs=bicep
// Creates: VNet, Bastion, 2 Ubuntu VMs for connectivity testing

@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual network name')
param vnetName string = 'vnet-1'

@description('Virtual network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Primary subnet name')
param subnetName string = 'subnet-1'

@description('Primary subnet address prefix')
param subnetAddressPrefix string = '10.0.0.0/24'

@description('Enable Azure Bastion deployment')
param enableBastion bool = true

@description('Azure Bastion host name')
param bastionName string = 'bastion'

@description('Bastion subnet address prefix (required /26)')
param bastionSubnetPrefix string = '10.0.1.0/26'

@description('VM administrator username')
param adminUsername string = 'azureuser'

@description('VM administrator password')
@secure()
param adminPassword string

@description('Virtual machine size')
param vmSize string = 'Standard_B2s'

@description('Operating system type')
@allowed(['Ubuntu', 'RHEL'])
param osType string = 'Ubuntu'

@description('Ubuntu OS version')
param ubuntuOSVersion string = '22_04-lts-gen2'

@description('RHEL OS version')
param rhelOSVersion string = '8_10'

// Variables for resource naming
var bastionPublicIpName = 'public-ip-bastion'
var nsgName = 'nsg-1'
var vm1Name = 'vm-1'
var vm2Name = 'vm-2'
var nic1Name = 'nic-vm-1'
var nic2Name = 'nic-vm-2'

// Image reference based on OS type
var imageReference = osType == 'Ubuntu' ? {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: ubuntuOSVersion
  version: 'latest'
} : {
  publisher: 'RedHat'
  offer: 'RHEL'
  sku: rhelOSVersion
  version: 'latest'
}

// Create Virtual Network with primary subnet
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          // Security Best Practice: SFI-NS2.6.1 - Disable default outbound connectivity
          defaultOutboundAccess: false
        }
      }
      // Conditionally add Bastion subnet if Bastion is enabled
      ...(enableBastion ? [
        {
          name: 'AzureBastionSubnet'
          properties: {
            addressPrefix: bastionSubnetPrefix
            // Security Best Practice: SFI-NS2.6.1 - Disable default outbound connectivity
            defaultOutboundAccess: false
          }
        }
      ] : [])
    ]
  }
}

// Create Public IP for Bastion (if enabled)
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = if (enableBastion) {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create Azure Bastion (if enabled)
resource bastionHost 'Microsoft.Network/bastionHosts@2023-09-01' = if (enableBastion) {
  name: bastionName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Create Network Security Group
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

// Create Network Interface for VM-1
resource networkInterface1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nic1Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Create Network Interface for VM-2
resource networkInterface2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nic2Name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
  dependsOn: [
    virtualNetwork
  ]
}

// Create Virtual Machine 1
resource virtualMachine1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm1Name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface1.id
        }
      ]
    }
    securityProfile: osType == 'Ubuntu' ? {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    } : null
  }
}

// Create Virtual Machine 2
resource virtualMachine2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vm2Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm2Name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface2.id
        }
      ]
    }
    securityProfile: osType == 'Ubuntu' ? {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    } : null
  }
}

// Outputs
output vnetName string = virtualNetwork.name
output vnetId string = virtualNetwork.id
output bastionName string = enableBastion ? bastionHost.name : 'Not deployed'
output vm1Name string = virtualMachine1.name  
output vm2Name string = virtualMachine2.name
output vm1PrivateIP string = networkInterface1.properties.ipConfigurations[0].properties.privateIPAddress
output vm2PrivateIP string = networkInterface2.properties.ipConfigurations[0].properties.privateIPAddress
