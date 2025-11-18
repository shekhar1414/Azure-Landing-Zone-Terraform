terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  backend "azurerm" {
    # Configure in pipeline
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# =========================================
# RESOURCE GROUPS
# =========================================

resource "azurerm_resource_group" "identity" {
  name     = "rg-identity-${var.environment}-${var.location_short}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "connectivity" {
  name     = "rg-connectivity-${var.environment}-${var.location_short}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "backend_dev" {
  name     = "rg-backend-dev-${var.environment}-${var.location_short}"
  location = var.location
  tags     = merge(var.tags, { Environment = "Development" })
}

resource "azurerm_resource_group" "backend_test" {
  name     = "rg-backend-test-${var.environment}-${var.location_short}"
  location = var.location
  tags     = merge(var.tags, { Environment = "Test" })
}

resource "azurerm_resource_group" "backend_prod" {
  name     = "rg-backend-prod-${var.environment}-${var.location_short}"
  location = var.location
  tags     = merge(var.tags, { Environment = "Production" })
}

resource "azurerm_resource_group" "public_services" {
  name     = "rg-publicservices-${var.environment}-${var.location_short}"
  location = var.location
  tags     = merge(var.tags, { Environment = "Public" })
}

# =========================================
# IDENTITY RG - LOG ANALYTICS
# =========================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# =========================================
# IDENTITY RG - KEY VAULT
# =========================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.environment}-${var.location_short}-${random_string.kv_suffix.result}"
  location                   = azurerm_resource_group.identity.location
  resource_group_name        = azurerm_resource_group.identity.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = var.tags
}

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault_access_policy" "terraform_sp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover"
  ]
}

# Store admin password in Key Vault
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.terraform_sp]
}

# =========================================
# IDENTITY RG - RECOVERY SERVICES VAULT
# =========================================

resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = var.tags
}

resource "azurerm_backup_policy_vm" "main" {
  name                = "backup-policy-vm-daily"
  resource_group_name = azurerm_resource_group.identity.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
}

# =========================================
# CONNECTIVITY RG - HUB VNET
# =========================================

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = ["10.0.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/27"]
}

# =========================================
# CONNECTIVITY RG - AZURE FIREWALL
# =========================================

resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall" "main" {
  name                = "afw-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# Firewall Network Rules - Allow ICMP and SSH between all VNets
resource "azurerm_firewall_network_rule_collection" "internal_traffic" {
  name                = "internal-traffic"
  azure_firewall_name = azurerm_firewall.main.name
  resource_group_name = azurerm_resource_group.connectivity.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "allow-icmp"
    source_addresses = [
      "10.0.0.0/8"
    ]
    destination_addresses = [
      "10.0.0.0/8"
    ]
    destination_ports = ["*"]
    protocols         = ["ICMP"]
  }

  rule {
    name = "allow-ssh"
    source_addresses = [
      "10.0.0.0/8"
    ]
    destination_addresses = [
      "10.0.0.0/8"
    ]
    destination_ports = ["22"]
    protocols         = ["TCP"]
  }
}

# Firewall Application Rules - Allow outbound internet
resource "azurerm_firewall_application_rule_collection" "internet_outbound" {
  name                = "internet-outbound"
  azure_firewall_name = azurerm_firewall.main.name
  resource_group_name = azurerm_resource_group.connectivity.name
  priority            = 200
  action              = "Allow"

  rule {
    name = "allow-internet"
    source_addresses = [
      "10.0.0.0/8"
    ]
    target_fqdns = ["*"]
    protocol {
      port = "80"
      type = "Http"
    }
    protocol {
      port = "443"
      type = "Https"
    }
  }
}

# =========================================
# CONNECTIVITY RG - AZURE BASTION
# =========================================

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku                 = "Standard"
  
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

# =========================================
# CONNECTIVITY RG - NETWORK WATCHER
# =========================================

resource "azurerm_network_watcher" "main" {
  name                = "nw-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = var.tags
}

# =========================================
# BACKEND DEV - VNET AND VM
# =========================================

resource "azurerm_virtual_network" "backend_dev" {
  name                = "vnet-backend-dev-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_dev.location
  resource_group_name = azurerm_resource_group.backend_dev.name
  address_space       = ["10.1.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "backend_dev_vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.backend_dev.name
  virtual_network_name = azurerm_virtual_network.backend_dev.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_security_group" "backend_dev" {
  name                = "nsg-backend-dev-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_dev.location
  resource_group_name = azurerm_resource_group.backend_dev.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ICMP-Internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "backend_dev" {
  subnet_id                 = azurerm_subnet.backend_dev_vms.id
  network_security_group_id = azurerm_network_security_group.backend_dev.id
}

resource "azurerm_network_interface" "backend_dev_vm" {
  name                = "nic-documentcorepack-dev"
  location            = azurerm_resource_group.backend_dev.location
  resource_group_name = azurerm_resource_group.backend_dev.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_dev_vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "backend_dev" {
  name                            = "vm-documentcorepack-dev"
  location                        = azurerm_resource_group.backend_dev.location
  resource_group_name             = azurerm_resource_group.backend_dev.name
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.backend_dev_vm.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# =========================================
# BACKEND TEST - VNET AND VM
# =========================================

resource "azurerm_virtual_network" "backend_test" {
  name                = "vnet-backend-test-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_test.location
  resource_group_name = azurerm_resource_group.backend_test.name
  address_space       = ["10.2.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "backend_test_vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.backend_test.name
  virtual_network_name = azurerm_virtual_network.backend_test.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_network_security_group" "backend_test" {
  name                = "nsg-backend-test-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_test.location
  resource_group_name = azurerm_resource_group.backend_test.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ICMP-Internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "backend_test" {
  subnet_id                 = azurerm_subnet.backend_test_vms.id
  network_security_group_id = azurerm_network_security_group.backend_test.id
}

resource "azurerm_network_interface" "backend_test_vm" {
  name                = "nic-documentcorepack-test"
  location            = azurerm_resource_group.backend_test.location
  resource_group_name = azurerm_resource_group.backend_test.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_test_vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "backend_test" {
  name                            = "vm-documentcorepack-test"
  location                        = azurerm_resource_group.backend_test.location
  resource_group_name             = azurerm_resource_group.backend_test.name
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.backend_test_vm.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# =========================================
# BACKEND PROD - VNET AND VM
# =========================================

resource "azurerm_virtual_network" "backend_prod" {
  name                = "vnet-backend-prod-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_prod.location
  resource_group_name = azurerm_resource_group.backend_prod.name
  address_space       = ["10.3.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "backend_prod_vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.backend_prod.name
  virtual_network_name = azurerm_virtual_network.backend_prod.name
  address_prefixes     = ["10.3.1.0/24"]
}

resource "azurerm_network_security_group" "backend_prod" {
  name                = "nsg-backend-prod-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_prod.location
  resource_group_name = azurerm_resource_group.backend_prod.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ICMP-Internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "backend_prod" {
  subnet_id                 = azurerm_subnet.backend_prod_vms.id
  network_security_group_id = azurerm_network_security_group.backend_prod.id
}

resource "azurerm_network_interface" "backend_prod_vm" {
  name                = "nic-documentcorepack-prod"
  location            = azurerm_resource_group.backend_prod.location
  resource_group_name = azurerm_resource_group.backend_prod.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend_prod_vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "backend_prod" {
  name                            = "vm-documentcorepack-prod"
  location                        = azurerm_resource_group.backend_prod.location
  resource_group_name             = azurerm_resource_group.backend_prod.name
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.backend_prod_vm.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# =========================================
# PUBLIC SERVICES - VNET AND VM
# =========================================

resource "azurerm_virtual_network" "public_services" {
  name                = "vnet-publicservices-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.public_services.location
  resource_group_name = azurerm_resource_group.public_services.name
  address_space       = ["10.4.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "public_services_vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.public_services.name
  virtual_network_name = azurerm_virtual_network.public_services.name
  address_prefixes     = ["10.4.1.0/24"]
}

resource "azurerm_subnet" "public_services_aca" {
  name                 = "snet-aca"
  resource_group_name  = azurerm_resource_group.public_services.name
  virtual_network_name = azurerm_virtual_network.public_services.name
  address_prefixes     = ["10.4.2.0/23"]
}

resource "azurerm_network_security_group" "public_services" {
  name                = "nsg-publicservices-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.public_services.location
  resource_group_name = azurerm_resource_group.public_services.name
  tags                = var.tags

  security_rule {
    name                       = "Allow-SSH-Internal"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-ICMP-Internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "public_services" {
  subnet_id                 = azurerm_subnet.public_services_vms.id
  network_security_group_id = azurerm_network_security_group.public_services.id
}

resource "azurerm_network_interface" "listserv_vm" {
  name                = "nic-listserv"
  location            = azurerm_resource_group.public_services.location
  resource_group_name = azurerm_resource_group.public_services.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_services_vms.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "listserv" {
  name                            = "vm-listserv"
  location                        = azurerm_resource_group.public_services.location
  resource_group_name             = azurerm_resource_group.public_services.name
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.listserv_vm.id]
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

# =========================================
# PUBLIC SERVICES - CONTAINER APP ENVIRONMENT
# =========================================

resource "azurerm_log_analytics_workspace" "aca" {
  name                = "law-aca-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.public_services.location
  resource_group_name = azurerm_resource_group.public_services.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.environment}-${var.location_short}"
  location                   = azurerm_resource_group.public_services.location
  resource_group_name        = azurerm_resource_group.public_services.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aca.id
  infrastructure_subnet_id   = azurerm_subnet.public_services_aca.id
  tags                       = var.tags
}

# Note: Container App for 1Password SCIM needs to be configured with specific image and secrets
# This is a placeholder structure
resource "azurerm_container_app" "onepassword_scim" {
  name                         = "ca-onepassword-scim"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.public_services.name
  revision_mode                = "Single"
  tags                         = var.tags

  template {
    container {
      name   = "onepassword-scim"
      image  = "1password/scim:latest"
      cpu    = 0.5
      memory = "1Gi"
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# =========================================
# VNET PEERING - HUB TO SPOKES
# =========================================

# Hub to Backend Dev
resource "azurerm_virtual_network_peering" "hub_to_backend_dev" {
  name                      = "peer-hub-to-backend-dev"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.backend_dev.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "backend_dev_to_hub" {
  name                      = "peer-backend-dev-to-hub"
  resource_group_name       = azurerm_resource_group.backend_dev.name
  virtual_network_name      = azurerm_virtual_network.backend_dev.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false
}

# Hub to Backend Test
resource "azurerm_virtual_network_peering" "hub_to_backend_test" {
  name                      = "peer-hub-to-backend-test"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.backend_test.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "backend_test_to_hub" {
  name                      = "peer-backend-test-to-hub"
  resource_group_name       = azurerm_resource_group.backend_test.name
  virtual_network_name      = azurerm_virtual_network.backend_test.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false
}

# Hub to Backend Prod
resource "azurerm_virtual_network_peering" "hub_to_backend_prod" {
  name                      = "peer-hub-to-backend-prod"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.backend_prod.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "backend_prod_to_hub" {
  name                      = "peer-backend-prod-to-hub"
  resource_group_name       = azurerm_resource_group.backend_prod.name
  virtual_network_name      = azurerm_virtual_network.backend_prod.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false
}

# Hub to Public Services
resource "azurerm_virtual_network_peering" "hub_to_public_services" {
  name                      = "peer-hub-to-publicservices"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.public_services.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "public_services_to_hub" {
  name                      = "peer-publicservices-to-hub"
  resource_group_name       = azurerm_resource_group.public_services.name
  virtual_network_name      = azurerm_virtual_network.public_services.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false
}

# =========================================
# ROUTE TABLES FOR SPOKE VNETS
# =========================================

# Route table for Backend Dev
resource "azurerm_route_table" "backend_dev" {
  name                = "rt-backend-dev-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_dev.location
  resource_group_name = azurerm_resource_group.backend_dev.name
  tags                = var.tags

  route {
    name                   = "to-internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "backend_dev" {
  subnet_id      = azurerm_subnet.backend_dev_vms.id
  route_table_id = azurerm_route_table.backend_dev.id
}

# Route table for Backend Test
resource "azurerm_route_table" "backend_test" {
  name                = "rt-backend-test-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_test.location
  resource_group_name = azurerm_resource_group.backend_test.name
  tags                = var.tags

  route {
    name                   = "to-internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "backend_test" {
  subnet_id      = azurerm_subnet.backend_test_vms.id
  route_table_id = azurerm_route_table.backend_test.id
}

# Route table for Backend Prod
resource "azurerm_route_table" "backend_prod" {
  name                = "rt-backend-prod-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.backend_prod.location
  resource_group_name = azurerm_resource_group.backend_prod.name
  tags                = var.tags

  route {
    name                   = "to-internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "backend_prod" {
  subnet_id      = azurerm_subnet.backend_prod_vms.id
  route_table_id = azurerm_route_table.backend_prod.id
}

# Route table for Public Services
resource "azurerm_route_table" "public_services" {
  name                = "rt-publicservices-${var.environment}-${var.location_short}"
  location            = azurerm_resource_group.public_services.location
  resource_group_name = azurerm_resource_group.public_services.name
  tags                = var.tags

  route {
    name                   = "to-internet-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "public_services" {
  subnet_id      = azurerm_subnet.public_services_vms.id
  route_table_id = azurerm_route_table.public_services.id
}
