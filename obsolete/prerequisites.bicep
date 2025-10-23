// ================================================================
// Prerequisites Template - Resource Group and Provider Registration
// ================================================================
// This template creates resource group and ensures required providers are registered
// Deploy this first before the main VMSS infrastructure

targetScope = 'subscription'

// ================================================================
// PARAMETERS
// ================================================================

@description('Project name for resource naming')
param projectName string = 'mda'

@description('Environment (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('The Azure region for deployment')
param location string = 'West US 2'

@description('Resource tags to apply to all resources')
param tags object = {}

// ================================================================
// VARIABLES
// ================================================================

// Location abbreviations for naming convention
var locationShort = {
  'West US 2': 'wus2'
  'East US': 'eus'
  'East US 2': 'eus2'
  'Central US': 'cus'
  'West Central US': 'wcus'
  'South Central US': 'scus'
  'North Central US': 'ncus'
  'West US': 'wus'
  'West US 3': 'wus3'
  'Canada Central': 'cac'
  'Canada East': 'cae'
  'Brazil South': 'brs'
  'North Europe': 'neu'
  'West Europe': 'weu'
  'UK South': 'uks'
  'UK West': 'ukw'
  'France Central': 'frc'
  'Germany West Central': 'gwc'
  'Switzerland North': 'swn'
  'Norway East': 'noe'
  'Sweden Central': 'swc'
  'Australia East': 'aue'
  'Australia Southeast': 'ause'
  'Southeast Asia': 'sea'
  'East Asia': 'ea'
  'Japan East': 'jpe'
  'Japan West': 'jpw'
  'Korea Central': 'krc'
  'Korea South': 'krs'
  'India Central': 'inc'
  'India South': 'ins'
  'India West': 'inw'
}[location] ?? take(replace(toLower(location), ' ', ''), 4)

// Resource group name following Azure naming conventions
// Format: rg-{project}-{workload}-{environment}-{location}
var resourceGroupName = 'rg-${projectName}-vmss-${environment}-${locationShort}'

// Combined resource tags
var resourceTags = union({
  Project: projectName
  Environment: environment
  Purpose: 'RHEL-VMSS-X11'
  Security: 'ZeroTrust'
  CreatedBy: 'Bicep'
  Workload: 'VMSS'
}, tags)

// Required Azure resource providers for VMSS deployment
var requiredProviders = [
  'Microsoft.Compute'           // Virtual Machine Scale Sets, VMs
  'Microsoft.Network'           // VNet, Load Balancers, Bastion
  'Microsoft.Storage'           // Storage accounts (if needed)
  'Microsoft.KeyVault'          // Key Vault for secrets
  'Microsoft.Insights'          // Azure Monitor, Application Insights
  'Microsoft.OperationalInsights' // Log Analytics
  'Microsoft.OperationsManagement' // Monitoring solutions
  'Microsoft.Security'          // Security Center integration
  'Microsoft.Authorization'     // RBAC and policy
  'Microsoft.Resources'         // Resource management
  'Microsoft.ManagedIdentity'   // Managed identities
  'Microsoft.AlertsManagement' // Alert management
]

// ================================================================
// RESOURCE PROVIDERS REGISTRATION
// ================================================================

// Note: Azure automatically registers resource providers when you deploy resources
// The following providers will be auto-registered during main deployment:
// - Microsoft.Compute (for VMSS and VMs)
// - Microsoft.Network (for VNet, Load Balancers, Bastion)  
// - Microsoft.Insights (for monitoring)
// - Microsoft.OperationalInsights (for Log Analytics)
// - Microsoft.OperationsManagement (for monitoring solutions)

// For manual registration, use Azure CLI:
// az provider register --namespace Microsoft.Compute
// az provider register --namespace Microsoft.Network
// etc.

// ================================================================
// RESOURCE GROUP
// ================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: resourceTags
  properties: {}
}

// ================================================================
// ROLE ASSIGNMENTS (Optional - for managed identities)
// ================================================================

// This section can be used to pre-assign roles if needed
// Currently commented out as it's typically done in the main deployment

/*
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role
}

resource vmContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c' // Virtual Machine Contributor
}
*/

// ================================================================
// SUBSCRIPTION LIMITS CHECK (Informational)
// ================================================================

// Note: These are for informational purposes - actual quota checks happen at deployment time

// ================================================================
// OUTPUTS
// ================================================================

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output location string = resourceGroup.location
output namingPrefix string = '${projectName}-${environment}-${locationShort}'
output subscriptionId string = subscription().subscriptionId
output tenantId string = subscription().tenantId

// Resource provider status (informational)
output requiredProviders array = requiredProviders
output providerRegistrationNote string = 'Providers are automatically registered when resources are deployed'

// Naming convention examples
output namingExamples object = {
  resourceGroup: resourceGroupName
  virtualNetwork: 'vnet-${projectName}-${environment}-${locationShort}'
  vmss: 'vmss-${projectName}-${environment}-${locationShort}'
  loadBalancer: 'lb-${projectName}-${environment}-${locationShort}'
  bastion: 'bas-${projectName}-${environment}-${locationShort}'
  logAnalytics: 'log-${projectName}-${environment}-${locationShort}'
  keyVault: 'kv-${projectName}${environment}${locationShort}${take(uniqueString(subscription().subscriptionId), 6)}'
  storageAccount: 'st${projectName}${environment}${locationShort}${take(uniqueString(subscription().subscriptionId), 6)}'
}

// Deployment instructions
output nextSteps array = [
  '1. Review the created resource group: ${resourceGroupName}'
  '2. Verify the location is correct: ${location}'
  '3. Update parameters.json with your SSH public key'
  '4. Deploy main infrastructure: az deployment group create --resource-group ${resourceGroupName} --template-file main.bicep --parameters @parameters.json'
  '5. Monitor deployment in Azure Portal'
]

// Security recommendations
output securityRecommendations array = [
  'Enable Azure Security Center for the subscription'
  'Configure Azure Policy for governance'
  'Set up Azure Monitor for comprehensive monitoring'
  'Review and configure network security groups'
  'Implement proper RBAC assignments'
  'Enable Azure Backup for critical data'
]

// Cost optimization tips
output costOptimization array = [
  'Use auto-scaling to optimize costs based on demand'
  'Consider Azure Reserved Instances for production workloads'
  'Monitor costs with Azure Cost Management'
  'Use appropriate VM sizes for your workload'
  'Implement proper shutdown policies for dev/test environments'
]