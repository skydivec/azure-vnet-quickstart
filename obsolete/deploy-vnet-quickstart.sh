#!/bin/bash

# Azure Virtual Network Quickstart - Azure CLI Deployment
# Based on: https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network?tabs=bicep

set -euo pipefail

# Script configuration
SCRIPT_NAME="Azure VNet Quickstart"
REQUIRED_CLI_VERSION="2.0.31"

# Default parameters
RESOURCE_GROUP=""
LOCATION="eastus2"
TEMPLATE_FILE="templates/main.bicep"
PARAMETERS_FILE="parameters/main.parameters.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "${CYAN}$1${NC}"
}

# Usage function
usage() {
    echo "Usage: $0 -g <resource-group> [-l <location>] [-t <template-file>] [-p <parameters-file>]"
    echo ""
    echo "Parameters:"
    echo "  -g  Resource group name (required)"
    echo "  -l  Azure location (default: eastus2)"
    echo "  -t  Bicep template file (default: templates/main.bicep)"
    echo "  -p  Parameters file (default: parameters/main.parameters.json)"
    echo "  -h  Show this help"
    echo ""
    echo "Example:"
    echo "  $0 -g test-rg -l eastus2"
    exit 1
}

# Parse command line arguments
while getopts "g:l:t:p:h" opt; do
    case $opt in
        g) RESOURCE_GROUP="$OPTARG";;
        l) LOCATION="$OPTARG";;
        t) TEMPLATE_FILE="$OPTARG";;
        p) PARAMETERS_FILE="$OPTARG";;
        h) usage;;
        *) usage;;
    esac
done

# Validate required parameters
if [ -z "$RESOURCE_GROUP" ]; then
    log_error "Resource group name is required"
    usage
fi

# Script header
echo -e "${GREEN}$SCRIPT_NAME${NC}"
echo "======================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo ""

# Check Azure CLI installation
log_step "Checking prerequisites..."
if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check CLI version
CLI_VERSION=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "0.0.0")
log_info "Azure CLI version: $CLI_VERSION"

# Verify Azure authentication
if ! az account show &> /dev/null; then
    log_step "Authenticating to Azure..."
    az login
else
    ACCOUNT_INFO=$(az account show --query '{name:name, user:user.name, tenantId:tenantId}' -o table 2>/dev/null)
    log_info "Already authenticated to Azure"
    echo "$ACCOUNT_INFO"
fi

# Create resource group
log_step "Managing resource group..."
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    log_info "Resource group exists: $RESOURCE_GROUP"
else
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    log_info "Resource group created: $RESOURCE_GROUP"
fi

# Validate template
log_step "Validating Bicep template..."
if az deployment group validate \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --output none 2>/dev/null; then
    log_info "Template validation passed"
else
    log_warn "Template validation failed - continuing anyway"
fi

# Get VM admin password
log_step "VM Configuration:"
echo -n "Enter password for VM administrator: "
read -s ADMIN_PASSWORD
echo ""

if [ ${#ADMIN_PASSWORD} -lt 8 ]; then
    log_error "Password must be at least 8 characters long"
    exit 1
fi

# Deploy template
log_step "Deploying infrastructure..."
DEPLOYMENT_NAME="VNetQuickstart-$(date +%Y%m%d-%H%M%S)"
START_TIME=$(date +%s)

echo "Starting deployment: $DEPLOYMENT_NAME"

if DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "@$PARAMETERS_FILE" \
    --parameters adminPassword="$ADMIN_PASSWORD" \
    --query 'properties.{state:provisioningState,duration:duration,outputs:outputs}' \
    --output json 2>/dev/null); then
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    log_info "Deployment completed successfully!"
    echo "Duration: ${DURATION}s"
    
    # Display outputs
    echo ""
    log_step "Deployment Results:"
    echo "=================="
    echo "$DEPLOYMENT_OUTPUT" | jq -r '.outputs | to_entries[] | "\(.key): \(.value.value)"' 2>/dev/null || {
        echo "Unable to parse outputs - check Azure portal for details"
    }
else
    log_error "Deployment failed"
    exit 1
fi

# Success summary
echo ""
log_step "Deployment Summary:"
echo "=================="
log_info "Virtual Network with subnets created"
log_info "Azure Bastion deployed for secure access"
log_info "Two Ubuntu VMs ready for testing"
log_info "Network security group configured"

echo ""
log_step "Next Steps:"
echo "1. Connect to VMs via Azure Bastion in Azure portal"
echo "2. Test connectivity: ping vm-2 from vm-1"
echo "3. Clean up resources: az group delete --name $RESOURCE_GROUP --yes"

echo ""
echo -e "${CYAN}💡 Tip: Access the Azure portal at https://portal.azure.com${NC}"