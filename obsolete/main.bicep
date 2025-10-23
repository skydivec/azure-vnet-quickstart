// ================================================================
// Secure Azure VMSS with RHEL 8.10 and X11 Remote Desktop
// ================================================================
// This template orchestrates deployment of a secure VMSS with zero trust principles
// Features: RHEL 8.10, Standard_A10 VMs, X11 GUI, security hardening

targetScope = 'resourceGroup'

// ================================================================
// PARAMETERS
// ================================================================

@description('The Azure region for deployment')
param location string = resourceGroup().location

@description('Project name used for resource naming')
param projectName string = 'mda-rhel-vmss'

@description('Environment (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Administrator username for VMSS instances')
param adminUsername string = 'azureuser'

@description('SSH public key for authentication')
param sshPublicKey string

@description('Number of VM instances in scale set')
@minValue(1)
@maxValue(100)
param instanceCount int = 3

@description('Virtual network address space')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address space for VMSS')
param vmssSubnetPrefix string = '10.0.1.0/24'

@description('Bastion subnet address space')
param bastionSubnetPrefix string = '10.0.2.0/26'

@description('Deploy Azure Bastion for secure access')
param deployBastion bool = true

@description('Enable monitoring and security features')
param enableMonitoring bool = true

@description('Enable auto-scaling based on CPU metrics')
param enableAutoScaling bool = true

@description('Minimum number of instances for auto-scaling')
@minValue(1)
param minInstanceCount int = 2

@description('Maximum number of instances for auto-scaling')
@maxValue(1000)
param maxInstanceCount int = 10

// ================================================================
// VARIABLES
// ================================================================

var resourceTags = {
  Project: projectName
  Environment: environment
  Purpose: 'RHEL-VMSS-X11'
  Security: 'ZeroTrust'
  CreatedBy: 'Bicep'
}

// Azure naming convention variables
var locationShort = {
  'West US 2': 'wus2'
  'East US': 'eus'
  'East US 2': 'eus2'
  'Central US': 'cus'
  'West Europe': 'weu'
  'North Europe': 'neu'
  'Southeast Asia': 'sea'
  'Australia East': 'aue'
}[location] ?? take(replace(toLower(location), ' ', ''), 4)

var namingPrefix = '${projectName}-${environment}-${locationShort}'

var networkConfig = {
  vnetName: 'vnet-${namingPrefix}'
  vnetAddressPrefix: vnetAddressPrefix
  vmssSubnetName: 'snet-vmss-${namingPrefix}'
  vmssSubnetPrefix: vmssSubnetPrefix
  bastionSubnetName: 'AzureBastionSubnet'
  bastionSubnetPrefix: bastionSubnetPrefix
  nsgName: 'nsg-vmss-${namingPrefix}'
  bastionName: 'bas-${namingPrefix}'
}

var vmssConfig = {
  vmssName: 'vmss-${namingPrefix}'
  vmSize: 'Standard_A10'
  adminUsername: adminUsername
  sshPublicKey: sshPublicKey
  instanceCount: instanceCount
  imageReference: {
    publisher: 'RedHat'
    offer: 'RHEL'
    sku: '8_10'
    version: 'latest'
  }
}

// ================================================================
// NETWORK MODULE
// ================================================================

module networkModule 'modules/network.bicep' = {
  name: 'network-deployment'
  params: {
    location: location
    tags: resourceTags
    networkConfig: networkConfig
    deployBastion: deployBastion
  }
}

// ================================================================
// VMSS MODULE
// ================================================================

module vmssModule 'modules/vmss.bicep' = {
  name: 'vmss-deployment'
  params: {
    location: location
    tags: resourceTags
    vmssConfig: vmssConfig
    subnetId: networkModule.outputs.vmssSubnetId
    enableAutoScaling: enableAutoScaling
    minInstanceCount: minInstanceCount
    maxInstanceCount: maxInstanceCount
  }
  dependsOn: [
    networkModule
  ]
}

// ================================================================
// MONITORING MODULE
// ================================================================

module monitoringModule 'modules/monitoring.bicep' = if (enableMonitoring) {
  name: 'monitoring-deployment'
  params: {
    location: location
    tags: resourceTags
    namingPrefix: namingPrefix
    vmssResourceId: vmssModule.outputs.vmssResourceId
  }
  dependsOn: [
    vmssModule
  ]
}

// ================================================================
// OUTPUTS
// ================================================================

output resourceGroupName string = resourceGroup().name
output virtualNetworkId string = networkModule.outputs.virtualNetworkId
output vmssName string = vmssModule.outputs.vmssName
output vmssResourceId string = vmssModule.outputs.vmssResourceId
output bastionName string = deployBastion ? networkModule.outputs.bastionName : ''
output loadBalancerPublicIp string = vmssModule.outputs.loadBalancerPublicIp
output sshConnectionCommand string = 'Connect via Azure Bastion in Portal or SSH to Load Balancer IP'
output autoScalingEnabled string = enableAutoScaling ? 'Yes - Min: ${minInstanceCount}, Max: ${maxInstanceCount}' : 'No'
output monitoringEnabled string = enableMonitoring ? 'Azure Monitor and Log Analytics enabled' : 'Monitoring not deployed'

// Security and Access Information
output securityFeatures array = [
  'Zero Trust Network Architecture'
  'SSH Key Authentication Only'
  'Network Security Groups with Least Privilege'
  'Azure Bastion for Secure Access'
  'Encrypted VM Disks'
  'Security Center Integration'
  'Custom Script Extension for Hardening'
]

output x11AccessInstructions array = [
  '1. Connect to VM via Azure Bastion'
  '2. X11 server automatically configured during deployment'
  '3. Use X11 forwarding: ssh -X azureuser@<vm-ip>'
  '4. Start GUI applications: gnome-session or startx'
  '5. Access via VNC or X11 client from approved networks'
]