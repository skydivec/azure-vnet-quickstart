// ================================================================
// VMSS Module: Secure RHEL 8.10 Scale Set with X11
// ================================================================
// Creates VMSS with Standard_A10 VMs, security hardening, and X11 setup

// ================================================================
// PARAMETERS
// ================================================================

@description('The Azure region for deployment')
param location string

@description('Resource tags')
param tags object

@description('VMSS configuration object')
param vmssConfig object

@description('Subnet ID for VMSS placement')
param subnetId string

@description('Enable auto-scaling')
param enableAutoScaling bool

@description('Minimum instance count for auto-scaling')
param minInstanceCount int

@description('Maximum instance count for auto-scaling')
param maxInstanceCount int

// ================================================================
// VARIABLES
// ================================================================

var customData = base64(loadTextContent('../scripts/x11-setup.sh'))
var loadBalancerName = '${vmssConfig.vmssName}-lb'
var publicIpName = '${loadBalancerName}-pip'

// ================================================================
// PUBLIC IP FOR LOAD BALANCER
// ================================================================

resource loadBalancerPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: '${vmssConfig.vmssName}-${uniqueString(resourceGroup().id)}'
    }
  }
}

// ================================================================
// LOAD BALANCER
// ================================================================

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: loadBalancerName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          publicIPAddress: {
            id: loadBalancerPublicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
      }
    ]
    loadBalancingRules: [
      {
        name: 'SSH'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'backendPool')
          }
          protocol: 'Tcp'
          frontendPort: 22
          backendPort: 22
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'sshProbe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'sshProbe'
        properties: {
          protocol: 'Tcp'
          port: 22
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    inboundNatPools: [
      {
        name: 'natPoolSSH'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', loadBalancerName, 'frontend')
          }
          protocol: 'Tcp'
          frontendPortRangeStart: 50000
          frontendPortRangeEnd: 50099
          backendPort: 22
        }
      }
    ]
  }
}

// ================================================================
// VIRTUAL MACHINE SCALE SET
// ================================================================

resource virtualMachineScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' = {
  name: vmssConfig.vmssName
  location: location
  tags: tags
  sku: {
    name: vmssConfig.vmSize
    tier: 'Standard'
    capacity: vmssConfig.instanceCount
  }
  properties: {
    upgradePolicy: {
      mode: 'Automatic'
      automaticOSUpgradePolicy: {
        enableAutomaticOSUpgrade: true
        disableAutomaticRollback: false
      }
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'rhel'
        adminUsername: vmssConfig.adminUsername
        customData: customData
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${vmssConfig.adminUsername}/.ssh/authorized_keys'
                keyData: vmssConfig.sshPublicKey
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: vmssConfig.imageReference
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic-config'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: subnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, 'backendPool')
                      }
                    ]
                    loadBalancerInboundNatPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/inboundNatPools', loadBalancerName, 'natPoolSSH')
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'customScript'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                skipDos2Unix: false
              }
              protectedSettings: {
                commandToExecute: 'bash /var/lib/cloud/instance/user-data.txt'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    loadBalancer
  ]
}

// ================================================================
// AUTO-SCALING SETTINGS
// ================================================================

resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (enableAutoScaling) {
  name: '${vmssConfig.vmssName}-autoscale'
  location: location
  tags: tags
  properties: {
    enabled: true
    targetResourceUri: virtualMachineScaleSet.id
    profiles: [
      {
        name: 'defaultProfile'
        capacity: {
          minimum: string(minInstanceCount)
          maximum: string(maxInstanceCount)
          default: string(vmssConfig.instanceCount)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: virtualMachineScaleSet.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricResourceUri: virtualMachineScaleSet.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
        ]
      }
    ]
  }
}

// ================================================================
// OUTPUTS
// ================================================================

output vmssName string = virtualMachineScaleSet.name
output vmssResourceId string = virtualMachineScaleSet.id
output loadBalancerPublicIp string = loadBalancerPublicIp.properties.ipAddress
output loadBalancerFQDN string = loadBalancerPublicIp.properties.dnsSettings.fqdn
output sshConnectionString string = 'ssh -p 50000 ${vmssConfig.adminUsername}@${loadBalancerPublicIp.properties.dnsSettings.fqdn}'

// VMSS Configuration Summary
output vmssSummary object = {
  name: virtualMachineScaleSet.name
  vmSize: vmssConfig.vmSize
  osImage: '${vmssConfig.imageReference.publisher} ${vmssConfig.imageReference.offer} ${vmssConfig.imageReference.sku}'
  instanceCount: vmssConfig.instanceCount
  autoScalingEnabled: enableAutoScaling
  minInstances: enableAutoScaling ? minInstanceCount : vmssConfig.instanceCount
  maxInstances: enableAutoScaling ? maxInstanceCount : vmssConfig.instanceCount
  loadBalancerIP: loadBalancerPublicIp.properties.ipAddress
}