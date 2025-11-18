# Azure Landing Zone - Hub-Spoke Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

This Terraform configuration deploys a complete **Azure Landing Zone** with a secure **hub-spoke network topology**, centralized security controls, and multiple environment landing zones (Development, Test, Production, and Public Services).

## 📋 Table of Contents
- [Architecture Overview](#architecture-overview)
- [Network Topology Diagram](#network-topology-diagram)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Resource Details](#resource-details)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

This landing zone implements Azure's best practices for enterprise-scale cloud infrastructure with a **hub-spoke network topology**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AZURE LANDING ZONE ARCHITECTURE                      │
│                           Hub-Spoke Network Topology                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  IDENTITY RESOURCE GROUP (Shared Services)                                    │
│  ┌──────────────┐  ┌─────────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Key Vault   │  │ Log Analytics   │  │  Recovery    │  │   Network    │  │
│  │   (Secrets)  │  │   Workspace     │  │  Services    │  │   Watcher    │  │
│  │              │  │   (Monitoring)  │  │   Vault      │  │              │  │
│  └──────────────┘  └─────────────────┘  └──────────────┘  └──────────────┘  │
└───────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│  CONNECTIVITY RESOURCE GROUP (Hub Network - 10.0.0.0/16)                      │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                         HUB VIRTUAL NETWORK                             │ │
│  │                                                                         │ │
│  │  ┌────────────────┐    ┌────────────────┐    ┌────────────────┐      │ │
│  │  │ Azure Firewall │    │ Azure Bastion  │    │ Gateway Subnet │      │ │
│  │  │   (10.0.1.0/26)│    │  (10.0.2.0/26) │    │  (10.0.3.0/27) │      │ │
│  │  │                │    │                │    │                │      │ │
│  │  │ • Network Rules│    │ • Secure SSH   │    │ • VPN Gateway  │      │ │
│  │  │ • App Rules    │    │ • Secure RDP   │    │   (Future)     │      │ │
│  │  │ • ICMP + SSH   │    │                │    │                │      │ │
│  │  └────────────────┘    └────────────────┘    └────────────────┘      │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘
            │                   │                   │                   │
            │ VNet Peering      │ VNet Peering      │ VNet Peering      │ VNet Peering
            ▼                   ▼                   ▼                   ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ BACKEND-DEV RG   │  │ BACKEND-TEST RG  │  │ BACKEND-PROD RG  │  │ PUBLIC SERVICES  │
│  (10.1.0.0/16)   │  │  (10.2.0.0/16)   │  │  (10.3.0.0/16)   │  │  (10.4.0.0/16)   │
│                  │  │                  │  │                  │  │                  │
│ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
│ │  VNet Spoke  │ │  │ │  VNet Spoke  │ │  │ │  VNet Spoke  │ │  │ │  VNet Spoke  │ │
│ │              │ │  │ │              │ │  │ │              │ │  │ │              │ │
│ │ ┌──────────┐ │ │  │ │ ┌──────────┐ │ │  │ │ ┌──────────┐ │ │  │ │ ┌──────────┐ │ │
│ │ │  Linux   │ │ │  │ │ │  Linux   │ │ │  │ │ │  Linux   │ │ │  │ │ │ LISTSERV │ │ │
│ │ │    VM    │ │ │  │ │ │    VM    │ │ │  │ │ │    VM    │ │ │  │ │ │    VM    │ │ │
│ │ │Document- │ │ │  │ │ │Document- │ │ │  │ │ │Document- │ │ │  │ │ │  Linux   │ │ │
│ │ │CorePack  │ │ │  │ │ │CorePack  │ │ │  │ │ │CorePack  │ │ │  │ │ └──────────┘ │ │
│ │ └──────────┘ │ │  │ │ └──────────┘ │ │  │ │ └──────────┘ │ │  │ │              │ │
│ │              │ │  │ │              │ │  │ │              │ │  │ │ ┌──────────┐ │ │
│ │    NSG       │ │  │ │    NSG       │ │  │ │    NSG       │ │  │ │ │Container │ │ │
│ │ Route Table  │ │  │ │ Route Table  │ │  │ │ Route Table  │ │  │ │ │   App    │ │ │
│ └──────────────┘ │  │ └──────────────┘ │  │ └──────────────┘ │  │ │ │1Password │ │ │
│                  │  │                  │  │                  │  │ │ │   SCIM   │ │ │
└──────────────────┘  └──────────────────┘  └──────────────────┘  │ │ └──────────┘ │ │
                                                                   │ └──────────────┘ │
                                                                   └──────────────────┘

┌───────────────────────────────────────────────────────────────────────────────┐
│  TRAFFIC FLOW                                                                  │
│  • All spoke-to-spoke traffic routes through Azure Firewall                   │
│  • Internet-bound traffic controlled by Firewall (HTTP/HTTPS allowed)         │
│  • SSH and ICMP allowed between all internal networks (10.0.0.0/8)           │
│  • No public IPs on VMs - access via Azure Bastion only                       │
│  • VNet peering enables direct connectivity to hub                            │
└───────────────────────────────────────────────────────────────────────────────┘
```

## 🌐 Network Topology Diagram

```
Hub VNet: 10.0.0.0/16
├── Firewall Subnet: 10.0.1.0/26
├── Bastion Subnet: 10.0.2.0/26
└── Gateway Subnet: 10.0.3.0/27

Spoke VNets (peered to hub):
├── Backend-Dev: 10.1.0.0/16 → VM Subnet: 10.1.1.0/24
├── Backend-Test: 10.2.0.0/16 → VM Subnet: 10.2.1.0/24
├── Backend-Prod: 10.3.0.0/16 → VM Subnet: 10.3.1.0/24
└── Public Services: 10.4.0.0/16
    ├── VM Subnet: 10.4.1.0/24
    └── Container App Subnet: 10.4.2.0/23
```

## ✨ Key Features

### Network Architecture
- ✅ **Hub-Spoke Topology**: Centralized connectivity and security controls
- ✅ **VNet Peering**: High-bandwidth, low-latency connectivity between hub and spokes
- ✅ **Azure Firewall**: Centralized network and application layer traffic filtering
- ✅ **Route Tables**: Force tunnel all traffic through the firewall
- ✅ **Network Security Groups**: Granular security at subnet level

### Security
- 🔒 **Azure Bastion**: Secure RDP/SSH without public IP exposure
- 🔒 **Azure Key Vault**: Centralized secrets management
- 🔒 **Private IPs Only**: No direct internet exposure for VMs
- 🔒 **Firewall Rules**: Allow SSH and ICMP for internal networks
- 🔒 **Network Isolation**: Separate environments for dev/test/prod

### Monitoring & Operations
- 📊 **Log Analytics**: Centralized logging and monitoring
- 📊 **Network Watcher**: Network diagnostics and troubleshooting
- 📊 **Boot Diagnostics**: VM console access for troubleshooting
- 📊 **Recovery Services Vault**: Backup and disaster recovery

### Infrastructure
- 🖥️ **Linux VMs**: Ubuntu 22.04 LTS (Standard_B2pts_v2)
- 🖥️ **Container Apps**: 1Password SCIM bridge deployment
- 🖥️ **Multi-Environment**: Dev, Test, Prod, and Public Services landing zones

## 📦 Resource Details

### Resource Groups
| Resource Group | Purpose | Key Resources |
|----------------|---------|---------------|
| **rg-identity-nprd-cin** | Identity & Security | Key Vault, Log Analytics, Recovery Vault, Network Watcher |
| **rg-connectivity-nprd-cin** | Hub Network | VNet Hub, Azure Firewall, Azure Bastion |
| **rg-backend-dev-nprd-cin** | Development Landing Zone | VNet, Linux VM (DocumentCorePack), NSG, Route Table |
| **rg-backend-test-nprd-cin** | Test Landing Zone | VNet, Linux VM (DocumentCorePack), NSG, Route Table |
| **rg-backend-prod-nprd-cin** | Production Landing Zone | VNet, Linux VM (DocumentCorePack), NSG, Route Table |
| **rg-publicservices-nprd-cin** | Public Services | VNet, LISTSERV VM, Container App, 1Password SCIM |

### Virtual Machines
| VM Name | Resource Group | Size | OS | Purpose |
|---------|----------------|------|----|---------| 
| vm-documentcorepack-dev | rg-backend-dev | Standard_B2pts_v2 | Ubuntu 22.04 | Development environment |
| vm-documentcorepack-test | rg-backend-test | Standard_B2pts_v2 | Ubuntu 22.04 | Test environment |
| vm-documentcorepack-prod | rg-backend-prod | Standard_B2pts_v2 | Ubuntu 22.04 | Production environment |
| vm-listserv | rg-publicservices | Standard_B2pts_v2 | Ubuntu 22.04 | Email list management |

### Network Address Spaces
| Network | CIDR | Purpose |
|---------|------|---------|
| Hub VNet | 10.0.0.0/16 | Central connectivity hub |
| Backend-Dev VNet | 10.1.0.0/16 | Development spoke |
| Backend-Test VNet | 10.2.0.0/16 | Test spoke |
| Backend-Prod VNet | 10.3.0.0/16 | Production spoke |
| Public Services VNet | 10.4.0.0/16 | Public services spoke |

## 🚀 Prerequisites

Before deploying this infrastructure, ensure you have:

1. **Azure Subscription** with sufficient permissions
2. **Azure Service Principal** with Contributor role
3. **Terraform** installed (version 1.5 or higher)
4. **Azure CLI** installed and authenticated
5. **Azure DevOps** account (optional, for CI/CD pipeline)

## ⚡ Quick Start

### Option 1: Local Deployment

```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/azure-landing-zone-terraform.git
cd azure-landing-zone-terraform

# Initialize Terraform
terraform init

# Create terraform.tfvars file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# Set: subscription_id, client_id, client_secret, tenant_id, admin_password

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### Option 2: Azure DevOps Pipeline

See [Detailed Setup](#detailed-setup) section for complete pipeline configuration.

## 📖 Detailed Setup

### 1. Create Azure Service Principal

```bash
# Login to Azure
az login

# Create service principal
az ad sp create-for-rbac --name "terraform-sp-landing-zone" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR-SUBSCRIPTION-ID"
```

Save the output (clientId, clientSecret, tenantId) for later use.

### 2. Configure Azure DevOps (Optional)

#### Create Variable Group

1. Navigate to Azure DevOps → Pipelines → Library
2. Create a variable group named: `ACC-23377-AZURE-NPRD-AICAP`
3. Add the following variables:

| Variable | Value | Secret? |
|----------|-------|---------|
| ARM_CLIENT_ID | Your Service Principal Client ID | No |
| ARM_TENANT_ID | Your Azure Tenant ID | No |
| ARM_CLIENT_SECRET | Your Service Principal Secret | Yes ✓ |
| ARM_SUBSCRIPTION_ID | Your Azure Subscription ID | No |
| admin_password | VM admin password (e.g., VmAdmin!1234) | Yes ✓ |

#### Create Terraform State Storage

```bash
# Create resource group for state
az group create --name rg-terraform-state --location centralindia

# Create storage account (name must be globally unique)
az storage account create \
  --name sttfstateaicap \
  --resource-group rg-terraform-state \
  --location centralindia \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name sttfstateaicap

# Get storage account key
az storage account keys list \
  --resource-group rg-terraform-state \
  --account-name sttfstateaicap
```

#### Create Azure Pipeline

1. Navigate to Pipelines → Create Pipeline
2. Select your repository
3. Choose "Existing Azure Pipelines YAML file"
4. Select `/azure-pipelines.yml`
5. Save and run

### 3. Local Deployment Configuration

Create a `terraform.tfvars` file:

```hcl
# Authentication
subscription_id = "your-azure-subscription-id"
client_id       = "your-service-principal-client-id"
client_secret   = "your-service-principal-secret"
tenant_id       = "your-azure-tenant-id"

# VM Admin Password
admin_password  = "VmAdmin!1234"

# Environment Settings
environment    = "nprd"
location       = "centralindia"
location_short = "cin"

# VM Settings
vm_size          = "Standard_B2pts_v2"
vm_admin_username = "azureuser"

# Tags
tags = {
  Project     = "Azure Landing Zone"
  ManagedBy   = "Terraform"
  Environment = "Non-Production"
  Owner       = "Platform Team"
}
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check

# Plan deployment
terraform plan -out=tfplan

# Apply deployment
terraform apply tfplan
```

## 🔐 Security

### Network Security

- **No Public IPs**: All VMs use private IPs only
- **Azure Bastion**: Secure RDP/SSH access without exposing management ports
- **Network Security Groups**: Restrict traffic to internal networks (10.0.0.0/8)
- **Azure Firewall**: Centralized egress control with application and network rules

### Access Control

- **Key Vault**: Stores VM admin passwords securely
- **Service Principal**: Limited to Contributor role
- **RBAC**: Role-based access control for all resources

### Firewall Rules

**Network Rules:**
- Allow ICMP (ping) between all internal networks
- Allow SSH (port 22) between all internal networks

**Application Rules:**
- Allow HTTP (port 80) to internet
- Allow HTTPS (port 443) to internet

### Secure VM Access

#### Via Azure Bastion (Recommended)
```bash
# Access via Azure Portal:
1. Navigate to VM in Azure Portal
2. Click "Connect" → "Bastion"
3. Username: azureuser
4. Password: [from Key Vault]
```

#### Via SSH from Another VM
```bash
# From any VM to another VM using private IP
ssh azureuser@10.1.1.4  # Example: Connect to dev VM
```

## 📊 Monitoring

### Log Analytics Workspace

All resources send logs and metrics to centralized Log Analytics:

```kusto
# Query all firewall logs
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| order by TimeGenerated desc

# Query VM performance
Perf
| where ObjectName == "Processor"
| where CounterName == "% Processor Time"
| summarize avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
```

### Network Watcher

- **Connection Monitor**: Track connectivity between VMs
- **Network Performance Monitor**: Monitor latency and packet loss
- **NSG Flow Logs**: Analyze network traffic patterns

### Azure Monitor

- **VM Insights**: Performance and health monitoring
- **Alerts**: Set up alerts for critical metrics
- **Workbooks**: Custom dashboards and reports

## 🔍 Testing Connectivity

### SSH Between VMs

```bash
# From Backend-Dev VM to Backend-Test VM
ssh azureuser@10.2.1.4

# From Backend-Prod VM to Public Services VM
ssh azureuser@10.4.1.4
```

### ICMP (Ping) Testing

```bash
# Test connectivity from any VM
ping 10.1.1.4  # Backend-Dev VM
ping 10.2.1.4  # Backend-Test VM
ping 10.3.1.4  # Backend-Prod VM
ping 10.4.1.4  # Public Services VM
```

### Internet Connectivity

```bash
# Test internet access (via Firewall)
curl https://www.google.com
curl https://azure.microsoft.com
```

## 🛠️ Customization

### Change VM Size

Edit `variables.tf`:

```hcl
variable "vm_size" {
  default = "Standard_B4ms"  # Upgrade to 4 vCPU, 16 GB RAM
}
```

### Add Additional VM

Add to `main.tf`:

```hcl
resource "azurerm_linux_virtual_machine" "new_vm" {
  name                = "vm-new-application"
  location            = azurerm_resource_group.backend_dev.location
  resource_group_name = azurerm_resource_group.backend_dev.name
  size                = var.vm_size
  # ... rest of configuration
}
```

### Modify Network Address Spaces

Update VNet address spaces in `main.tf`:

```hcl
resource "azurerm_virtual_network" "backend_dev" {
  address_space = ["10.1.0.0/16"]  # Change as needed
}
```

### Add Custom Firewall Rules

```hcl
resource "azurerm_firewall_network_rule_collection" "custom" {
  name                = "custom-rules"
  azure_firewall_name = azurerm_firewall.main.name
  resource_group_name = azurerm_resource_group.connectivity.name
  priority            = 150
  action              = "Allow"

  rule {
    name = "allow-custom-port"
    source_addresses      = ["10.1.0.0/16"]
    destination_addresses = ["10.2.0.0/16"]
    destination_ports     = ["8080"]
    protocols             = ["TCP"]
  }
}
```

## 🐛 Troubleshooting

### Common Issues

#### Issue: Terraform Init Fails

**Solution:**
```bash
# Check Azure CLI login
az account show

# Verify service principal
az login --service-principal \
  -u $ARM_CLIENT_ID \
  -p $ARM_CLIENT_SECRET \
  --tenant $ARM_TENANT_ID
```

#### Issue: VM Connection Timeout

**Possible Causes:**
1. NSG rules blocking traffic
2. Route table misconfiguration
3. Firewall blocking connections

**Solution:**
```bash
# Check NSG effective rules
az network nic show-effective-nsg \
  --name nic-documentcorepack-dev \
  --resource-group rg-backend-dev-nprd-cin

# Check route table
az network nic show-effective-route-table \
  --name nic-documentcorepack-dev \
  --resource-group rg-backend-dev-nprd-cin
```

#### Issue: Firewall Blocking Traffic

**Solution:**
```bash
# Check firewall logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallNetworkRule' | take 50"
```

#### Issue: Key Vault Access Denied

**Solution:**
```bash
# Grant access to service principal
az keyvault set-policy \
  --name kv-nprd-cin-xxxxxx \
  --spn $ARM_CLIENT_ID \
  --secret-permissions get list set delete
```

### Pipeline Failures

#### Terraform Plan Errors

1. Check variable group in Azure DevOps
2. Verify service connection credentials
3. Ensure storage account for state exists

#### Apply Fails with Quota Errors

**Solution:**
```bash
# Check subscription quotas
az vm list-usage --location centralindia --output table

# Request quota increase if needed
```

## 💰 Cost Estimation

Approximate monthly costs (Central India region):

| Resource | Quantity | Estimated Cost (USD) |
|----------|----------|---------------------|
| Azure Firewall (Standard) | 1 | $843.20 |
| Azure Bastion (Standard) | 1 | $140.16 |
| Linux VMs (B2pts_v2) | 4 | ~$40.00 |
| Log Analytics | 1 | ~$20.00 |
| Storage (Standard LRS) | 1 | ~$5.00 |
| **Total** | | **~$1,048.36/month** |

**Cost Optimization Tips:**
- Use Azure Hybrid Benefit if applicable
- Implement auto-shutdown schedules for dev/test VMs
- Use Reserved Instances for production workloads
- Consider Firewall Basic SKU for non-production

## 🧹 Clean Up

### Option 1: Terraform Destroy

```bash
# Destroy all resources
terraform destroy
```

### Option 2: Azure DevOps Pipeline

1. Navigate to pipeline
2. Run pipeline with Destroy stage enabled
3. Approve manual approval

### Option 3: Azure Portal

1. Delete each resource group manually
2. Verify all resources are removed

## 📚 Additional Resources

- [Azure Landing Zones Documentation](https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/)
- [Hub-Spoke Network Topology](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Firewall Documentation](https://docs.microsoft.com/en-us/azure/firewall/)
- [Azure Bastion Documentation](https://docs.microsoft.com/en-us/azure/bastion/)

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Platform Engineering Team**
- Project: ACC-23377-AZURE-NPRD-AICAP

## 🔖 Version History

| Version | Date | Changes |
|---------|------|---------|
| **1.0.0** | 2025-11-18 | Initial release with hub-spoke topology |
| | | - 4 Landing zones (Dev, Test, Prod, Public) |
| | | - Azure Firewall with network rules |
| | | - Azure Bastion for secure access |
| | | - Full VNet peering mesh |
| | | - Centralized logging and monitoring |

## 📞 Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Azure DevOps pipeline logs
3. Check Azure Portal for resource status
4. Open an issue in the repository

---

**Built with ❤️ using Terraform and Azure**
