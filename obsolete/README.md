# Secure Azure VMSS with RHEL 8.10 and X11 Remote Desktop

This project deploys a secure Azure Virtual Machine Scale Set (VMSS) running RHEL 8.10 on Standard_A10 VMs. It configures X11 remote desktop access and applies zero trust principles and VMSS security best practices.

## 🏗️ **Architecture Overview**

The solution implements a comprehensive zero-trust architecture with:

- **Secure Networking**: Virtual network with dedicated subnets and Network Security Groups
- **VMSS Deployment**: Auto-scalable RHEL 8.10 instances with Standard_A10 VMs  
- **X11 Remote Desktop**: VNC, XRDP, and SSH X11 forwarding capabilities
- **Security Monitoring**: Azure Monitor, Log Analytics, and security alerts
- **Zero Trust Access**: Azure Bastion for secure browser-based access

## 📁 **Project Structure**

```
MDA_RHEL8_A10_X11/
│
├── main.bicep                # Entry point: orchestrates the deployment
├── parameters.json           # Parameter values for deployment
├── README.md                 # Documentation and usage instructions
│
├── modules/                  # Reusable Bicep modules
│   ├── network.bicep         # VNet, subnet, NSG definitions
│   ├── vmss.bicep            # VMSS resource definition
│   └── monitoring.bicep      # Monitoring/logging resources
│
└── scripts/                  # Custom scripts for VM configuration
    └── x11-setup.sh          # Bash script for X11 and GUI setup
```

## 🔧 **Infrastructure Components**

### **Network Infrastructure**
- **Virtual Network**: Isolated network environment (10.0.0.0/16)
- **VMSS Subnet**: Dedicated subnet for scale set instances (10.0.1.0/24)
- **Bastion Subnet**: Azure Bastion subnet for secure access (10.0.2.0/26)
- **Network Security Groups**: Restrictive firewall rules with least privilege
- **Load Balancer**: Standard SKU with public IP and NAT rules

### **Compute Resources**  
- **VMSS**: Auto-scalable Red Hat Enterprise Linux 8.10 instances
- **VM Size**: Standard_A10 (8 vCPUs, 14GB RAM, 382GB temp storage)
- **Auto-scaling**: CPU-based scaling (2-10 instances, 30%-70% thresholds)
- **Storage**: Premium SSD managed disks with encryption

### **Security Features**
- **SSH Key Authentication**: Password authentication disabled
- **Azure Bastion**: Secure browser-based access (Standard SKU)
- **Network Isolation**: No direct internet access to VMs
- **Security Center Integration**: Continuous security monitoring
- **Fail2ban**: Intrusion detection and prevention

### **Monitoring & Logging**
- **Azure Monitor**: Comprehensive performance monitoring  
- **Log Analytics**: Centralized logging and analysis
- **Application Insights**: Application performance monitoring
- **Security Alerts**: Automated alerts for suspicious activities
- **Custom Workbooks**: VMSS-specific monitoring dashboards

## 🔑 **Prerequisites**

1. **Azure Subscription** with sufficient permissions
2. **Azure CLI** installed and authenticated
3. **SSH Key Pair** for VM authentication
4. **PowerShell 7+** (recommended) or Bash

### **Generate SSH Key**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/mda_vmss_key
cat ~/.ssh/mda_vmss_key.pub  # Copy this to parameters.json
```

## 🚀 **Deployment Instructions**

### **1. Prepare Parameters**
Edit `parameters.json` and update:
- `sshPublicKey`: Your SSH public key
- `location`: Preferred Azure region
- `instanceCount`: Initial number of VM instances

### **2. Deploy Infrastructure**
```bash
# Create resource group
az group create --name "rg-mda-rhel-vmss" --location "West US 2"

# Deploy infrastructure
az deployment group create \
  --resource-group "rg-mda-rhel-vmss" \
  --template-file "main.bicep" \
  --parameters "@parameters.json" \
  --name "mda-vmss-deployment"
```

### **3. Validate Deployment**
```bash
# Check deployment status
az deployment group show \
  --resource-group "rg-mda-rhel-vmss" \
  --name "mda-vmss-deployment" \
  --query "properties.provisioningState"

# List created resources
az resource list --resource-group "rg-mda-rhel-vmss" --output table
```

## 🖥️ **Connecting to VMSS Instances**

### **Option 1: Azure Bastion (Recommended)**
1. **Navigate** to Azure Portal → Virtual Machine Scale Sets
2. **Select** your VMSS instance → **Connect** → **Bastion**
3. **Enter** username and SSH private key
4. **Connect** via secure browser session

### **Option 2: SSH with X11 Forwarding**
```bash
# Connect with X11 forwarding enabled
ssh -X -p 50000 azureuser@<load-balancer-fqdn>

# Start GUI applications
firefox &
gnome-session &
```

### **Option 3: VNC Client**
1. **Connect** via SSH or Bastion first
2. **Start VNC server**: `vncserver :1`
3. **Create SSH tunnel**: `ssh -L 5901:localhost:5901 azureuser@<vm-ip>`
4. **Connect VNC client** to `localhost:5901`

### **Option 4: RDP Client**
1. **Connect** to any VMSS instance via Bastion
2. **Use RDP client** to connect to `<vm-private-ip>:3389`
3. **Login** with same credentials

## 📊 **Monitoring and Management**

### **Azure Monitor Integration**
- **Performance Metrics**: CPU, Memory, Disk, Network utilization
- **Auto-scaling Events**: Scale-out/in activities and triggers  
- **Health Probes**: Load balancer health monitoring
- **Security Events**: Failed logins, suspicious activities

### **Custom Workbooks**
Access pre-configured monitoring dashboards:
1. **Navigate** to Azure Monitor → Workbooks
2. **Select** "MDA RHEL VMSS Monitoring Dashboard"
3. **Monitor** real-time performance and security metrics

### **Alerting Configuration**
Automated alerts configured for:
- **High CPU Usage** (>80% for 5 minutes)
- **Low Memory** (<1GB available)
- **Suspicious Login Activities** (>10 failed attempts)
- **Auto-scaling Events** (scale operations)

## 🔒 **Security Best Practices Implemented**

### **Zero Trust Principles**
- ✅ **Verify Explicitly**: Multi-factor authentication via SSH keys
- ✅ **Least Privilege Access**: Restrictive NSG rules and RBAC
- ✅ **Assume Breach**: Comprehensive monitoring and alerting

### **Network Security**
- ✅ **No Public IPs**: VMs accessible only via Bastion or Load Balancer
- ✅ **Network Segmentation**: Dedicated subnets with NSG protection
- ✅ **Service Endpoints**: Secure access to Azure services
- ✅ **DDoS Protection**: Standard DDoS protection on public IPs

### **Compute Security**
- ✅ **SSH Keys Only**: Password authentication disabled
- ✅ **Encrypted Storage**: Premium SSD with encryption at rest
- ✅ **Security Patches**: Automatic security updates enabled
- ✅ **Intrusion Detection**: fail2ban configured and running

### **Monitoring Security**
- ✅ **Security Center**: Continuous security assessments
- ✅ **Log Analytics**: Centralized security event logging
- ✅ **Alert Rules**: Automated threat detection and response
- ✅ **Audit Trails**: Complete activity logging and retention

## 🎮 **X11 and Remote Desktop Features**

### **Pre-installed GUI Applications**
- **GNOME Desktop Environment**: Full Linux desktop experience
- **Firefox Web Browser**: Internet browsing capabilities  
- **System Utilities**: htop, vim, git, wget, curl
- **Development Tools**: Ready for software development

### **Remote Access Methods**
| Method | Port | Protocol | Use Case |
|--------|------|----------|----------|
| SSH + X11 | 22 | SSH | Command line with GUI apps |
| VNC Server | 5901 | VNC | Full desktop via VNC client |
| XRDP Server | 3389 | RDP | Windows RDP client compatible |
| Azure Bastion | 443 | HTTPS | Secure browser-based access |

### **Default Credentials**
- **SSH Username**: `azureuser` (configured in parameters)
- **VNC Password**: `VncPassword123!` ⚠️ **Change this immediately!**
- **Authentication**: SSH key-based (no passwords allowed)

## ⚙️ **Configuration Parameters**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `projectName` | `mda-rhel-vmss` | Resource naming prefix |
| `environment` | `dev` | Environment tag (dev/test/prod) |
| `location` | `West US 2` | Azure region |
| `adminUsername` | `azureuser` | VM administrator username |
| `instanceCount` | `3` | Initial VMSS instance count |
| `enableAutoScaling` | `true` | Enable CPU-based auto-scaling |
| `minInstanceCount` | `2` | Minimum instances (auto-scaling) |
| `maxInstanceCount` | `10` | Maximum instances (auto-scaling) |
| `deployBastion` | `true` | Deploy Azure Bastion |
| `enableMonitoring` | `true` | Enable comprehensive monitoring |

## 💰 **Cost Optimization**

### **Standard_A10 VM Costs** (Approximate US West 2)
- **Compute**: ~$0.363/hour per instance
- **Storage**: ~$19.71/month per 127GB Premium SSD
- **Load Balancer**: ~$18.25/month for Standard SKU
- **Bastion**: ~$140/month for Standard SKU
- **Data Transfer**: Variable based on usage

### **Cost Optimization Tips**
1. **Auto-scaling**: Reduces costs during low-usage periods
2. **Dev/Test Pricing**: Use Azure Dev/Test subscriptions
3. **Reserved Instances**: Up to 72% savings for production workloads
4. **Scheduled Shutdown**: Stop VMs during non-business hours
5. **Monitor Usage**: Use Azure Cost Management tools

## 🛠️ **Troubleshooting**

### **Common Issues**

**Deployment Fails**
```bash
# Check deployment logs
az deployment group show --resource-group "rg-mda-rhel-vmss" --name "mda-vmss-deployment"
```

**Cannot Connect via Bastion**
- Verify SSH public key is correct in parameters
- Check VMSS instances are running
- Confirm Bastion is fully deployed

**X11 Applications Won't Start**
```bash
# Check X11 setup log
sudo cat /var/log/x11-setup.log

# Verify VNC server status  
vncserver -list

# Restart X11 services
sudo systemctl restart gdm
```

**Auto-scaling Not Working**
- Check metric alerts in Azure Monitor
- Verify CPU thresholds are configured correctly
- Monitor auto-scale activity logs

### **Getting Support**
1. **Check Azure Service Health** for regional issues
2. **Review deployment logs** for specific error messages  
3. **Monitor Application Insights** for application-level issues
4. **Use Azure Support** for infrastructure-related problems

## 🔄 **Maintenance and Updates**

### **Regular Maintenance Tasks**
- **Security Updates**: Automated via dnf-automatic
- **Scale Set Updates**: Use rolling upgrade policy
- **Backup Verification**: Regular backup testing
- **Performance Review**: Monthly performance analysis

### **Scaling Operations**
```bash
# Manual scaling
az vmss scale --resource-group "rg-mda-rhel-vmss" --name "mda-rhel-vmss-vmss" --new-capacity 5

# Update instance model
az vmss update-instances --resource-group "rg-mda-rhel-vmss" --name "mda-rhel-vmss-vmss" --instance-ids "*"
```

## 🧹 **Cleanup**

```bash
# Delete entire resource group and all resources
az group delete --name "rg-mda-rhel-vmss" --yes --no-wait
```

---

## 📞 **Support and Documentation**

- **Azure VMSS Documentation**: [aka.ms/azurevmss](https://docs.microsoft.com/azure/virtual-machine-scale-sets/)
- **RHEL 8.10 Documentation**: [access.redhat.com](https://access.redhat.com/documentation/)
- **X11 Forwarding Guide**: [ssh.com/academy/ssh/x11-forwarding](https://www.ssh.com/academy/ssh/x11-forwarding)
- **Azure Security Center**: [docs.microsoft.com/azure/security-center/](https://docs.microsoft.com/azure/security-center/)

**Project Version**: 1.0.0  
**Last Updated**: October 2025  
**Compatibility**: Azure Resource Manager, Bicep 0.29+