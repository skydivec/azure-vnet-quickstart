# Azure Virtual Network Quickstart with Bicep

This project implements the official Microsoft Learn tutorial for creating an Azure Virtual Network using Bicep templates. It demonstrates fundamental Azure networking concepts by deploying a virtual network with two Ubuntu virtual machines and secure connectivity through Azure Bastion.

## 📋 Overview

**Tutorial Source:** [Azure Virtual Network Quickstart](https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network?tabs=bicep)

### What This Project Creates

- **Virtual Network** (`vnet-1`) with address space `10.0.0.0/16`
- **Primary Subnet** (`subnet-1`) for VMs with range `10.0.0.0/24`
- **Azure Bastion** with dedicated subnet `AzureBastionSubnet` (`10.0.1.0/26`)
- **Two Ubuntu 22.04 LTS VMs** for connectivity testing
- **Network Security Group** with SSH access rules
- **Public IP** for Bastion host

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Resource Group                                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Virtual Network: vnet-1 (10.0.0.0/16)                      │ │
│ │ ┌─────────────────────┐ ┌─────────────────────────────────┐ │ │
│ │ │ subnet-1            │ │ AzureBastionSubnet              │ │ │
│ │ │ 10.0.0.0/24         │ │ 10.0.1.0/26                     │ │ │
│ │ │ ┌─────┐ ┌─────┐     │ │ ┌─────────────────────────────┐ │ │ │
│ │ │ │vm-1 │ │vm-2 │     │ │ │ Azure Bastion               │ │ │ │
│ │ │ │     │ │     │     │ │ │ + Public IP                 │ │ │ │
│ │ │ └─────┘ └─────┘     │ │ └─────────────────────────────┘ │ │ │
│ │ └─────────────────────┘ └─────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Azure subscription with appropriate permissions
- **PowerShell Option**: Azure PowerShell module installed
- **CLI Option**: Azure CLI installed (version 2.0.31+)

### Option 1: PowerShell Deployment

```powershell
# Navigate to project directory
cd C:\repos\MDA

# Run deployment script (auto-installs Azure PowerShell if needed)
.\scripts\Deploy-VNetQuickstart.ps1 -ResourceGroupName "test-rg"

# With custom location
.\scripts\Deploy-VNetQuickstart.ps1 -ResourceGroupName "my-vnet-rg" -Location "westus2"

# Skip automatic Azure PowerShell installation
.\scripts\Deploy-VNetQuickstart.ps1 -ResourceGroupName "test-rg" -SkipModuleInstall
```

### Option 2: Azure CLI Deployment

```bash
# Navigate to project directory  
cd /c/repos/MDA

# Make script executable (Linux/macOS)
chmod +x scripts/deploy-vnet-quickstart.sh

# Run deployment
./scripts/deploy-vnet-quickstart.sh -g "test-rg"

# With custom location
./scripts/deploy-vnet-quickstart.sh -g "my-vnet-rg" -l "westus2"
```

### Option 3: Manual Deployment

**PowerShell:**
```powershell
# Create resource group
New-AzResourceGroup -Name "test-rg" -Location "eastus2"

# Deploy template
New-AzResourceGroupDeployment `
    -ResourceGroupName "test-rg" `
    -TemplateFile "templates\main.bicep" `
    -TemplateParameterFile "parameters\main.parameters.json"
```

**Azure CLI:**
```bash
# Create resource group  
az group create --name test-rg --location eastus2

# Deploy template
az deployment group create \
    --resource-group test-rg \
    --template-file templates/main.bicep \
    --parameters @parameters/main.parameters.json
```

## 📁 Project Structure

```
MDA/
├── templates/
│   └── main.bicep                    # Main Bicep template
├── parameters/
│   └── main.parameters.json          # Template parameters
├── scripts/
│   ├── Deploy-VNetQuickstart.ps1     # PowerShell deployment
│   ├── deploy-vnet-quickstart.sh     # Bash deployment
│   └── Cleanup-VNetQuickstart.ps1    # Resource cleanup
├── obsolete/                         # Previous work (preserved)
└── README.md                         # This documentation
```

## ⚙️ Configuration Parameters

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `location` | Azure region | `eastus2` |
| `vnetName` | Virtual network name | `vnet-1` |
| `vnetAddressPrefix` | VNet CIDR block | `10.0.0.0/16` |
| `subnetName` | Primary subnet name | `subnet-1` |
| `subnetAddressPrefix` | Subnet CIDR | `10.0.0.0/24` |
| `enableBastion` | Deploy Bastion | `true` |
| `bastionName` | Bastion host name | `bastion` |
| `bastionSubnetPrefix` | Bastion subnet CIDR | `10.0.1.0/26` |
| `adminUsername` | VM administrator | `azureuser` |
| `vmSize` | Virtual machine SKU | `Standard_B2s` |

### Customizing the Deployment

Edit `parameters/main.parameters.json` to modify default values:

```json
{
  "parameters": {
    "vnetName": {
      "value": "my-custom-vnet"
    },
    "vmSize": {
      "value": "Standard_B1s"
    }
  }
}
```

## 🧪 Testing Network Connectivity

### Connect to Virtual Machines

1. **Open Azure Portal**: Navigate to [https://portal.azure.com](https://portal.azure.com)
2. **Find your VMs**: Search for "Virtual machines" → Select `vm-1`
3. **Connect via Bastion**: Click "Connect" → Select "Bastion" tab → "Use Bastion"
4. **Enter Credentials**: Use `azureuser` and the password you provided

### Test VM-to-VM Connectivity

1. **From vm-1 to vm-2:**
   ```bash
   azureuser@vm-1:~$ ping -c 4 vm-2
   ```

2. **Expected Output:**
   ```
   PING vm-2.internal.cloudapp.net (10.0.0.5) 56(84) bytes of data.
   64 bytes from vm-2.internal.cloudapp.net (10.0.0.5): icmp_seq=1 ttl=64 time=1.83 ms
   64 bytes from vm-2.internal.cloudapp.net (10.0.0.5): icmp_seq=2 ttl=64 time=0.987 ms
   64 bytes from vm-2.internal.cloudapp.net (10.0.0.5): icmp_seq=3 ttl=64 time=0.864 ms
   64 bytes from vm-2.internal.cloudapp.net (10.0.0.5): icmp_seq=4 ttl=64 time=0.890 ms
   ```

3. **Repeat from vm-2**: Connect to `vm-2` and ping `vm-1`

## 🔒 Security Features

- **Azure Bastion**: Secure RDP/SSH without public IPs on VMs
- **Network Security Groups**: Controlled traffic with SSH rule
- **Trusted Launch VMs**: Enhanced security with secure boot and vTPM
- **Private IP Communication**: VMs communicate via internal network only
- **Zone-Redundant Public IP**: High availability for Bastion

## 🧹 Resource Cleanup

### Automated Cleanup (PowerShell)

```powershell
# Preview what will be deleted
.\scripts\Cleanup-VNetQuickstart.ps1 -ResourceGroupName "test-rg" -WhatIf

# Delete all resources
.\scripts\Cleanup-VNetQuickstart.ps1 -ResourceGroupName "test-rg"

# Force delete without confirmation
.\scripts\Cleanup-VNetQuickstart.ps1 -ResourceGroupName "test-rg" -Force
```

### Manual Cleanup

**PowerShell:**
```powershell
Remove-AzResourceGroup -Name "test-rg" -Force
```

**Azure CLI:**
```bash
az group delete --name test-rg --yes --no-wait
```

## 💰 Cost Management

### Estimated Monthly Costs (USD)

| Resource | Cost |
|----------|------|
| Azure Bastion (Basic) | ~$140 |
| VM Standard_B2s (2x) | ~$60 |
| Public IP (Standard) | ~$3.50 |
| Managed Disks (2x) | ~$10 |
| **Total** | **~$213.50** |

### Cost Optimization Tips

- **Delete when not in use**: Use cleanup scripts after testing
- **Smaller VM sizes**: Use `Standard_B1s` for basic testing
- **Bastion alternatives**: Consider just-in-time VM access for development
- **Scheduled shutdown**: Use Azure automation to stop VMs automatically

## 🔧 Troubleshooting

### Common Issues

**Template Validation Errors:**
```bash
# Validate template syntax
az bicep build --file templates/main.bicep
```

**Authentication Problems:**
```bash
# Re-authenticate to Azure
az login
az account set --subscription "Your-Subscription-Name"
```

**Deployment Failures:**
1. Check Azure activity log in portal
2. Verify subscription limits and quotas
3. Ensure resource group doesn't already contain conflicting resources

### Getting Help

- **Azure Activity Log**: Monitor deployment progress in Azure Portal
- **Template Outputs**: Review deployment results for resource details  
- **Bastion Connectivity**: Ensure NSG rules allow Bastion traffic
- **VM Boot Diagnostics**: Check VM startup logs if connection fails

## 📚 Learning Resources

- [Azure Virtual Network Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/)
- [Azure Bastion Overview](https://docs.microsoft.com/en-us/azure/bastion/bastion-overview)
- [Bicep Language Reference](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Networking Fundamentals](https://docs.microsoft.com/en-us/azure/networking/fundamentals/)

## 🏷️ Tags and Metadata

This project automatically applies the following tags to resources:

- `project`: VNetQuickstart
- `source`: microsoft-learn-tutorial  
- `environment`: demo
- `created-by`: bicep-template

## 📄 License

This project follows the Microsoft Learn tutorial structure and is provided for educational purposes. See the original [Microsoft Learn tutorial](https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network?tabs=bicep) for additional terms.

---

**🎯 Tutorial Objective Achieved:** You've successfully implemented Azure Virtual Network fundamentals using Infrastructure as Code with Bicep templates, demonstrating secure VM connectivity through Azure Bastion in a production-ready configuration.