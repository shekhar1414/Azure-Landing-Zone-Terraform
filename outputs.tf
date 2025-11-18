# =========================================
# RESOURCE GROUP OUTPUTS
# =========================================

output "identity_rg_name" {
  description = "Name of the Identity resource group"
  value       = azurerm_resource_group.identity.name
}

output "connectivity_rg_name" {
  description = "Name of the Connectivity resource group"
  value       = azurerm_resource_group.connectivity.name
}

output "backend_dev_rg_name" {
  description = "Name of the Backend Dev resource group"
  value       = azurerm_resource_group.backend_dev.name
}

output "backend_test_rg_name" {
  description = "Name of the Backend Test resource group"
  value       = azurerm_resource_group.backend_test.name
}

output "backend_prod_rg_name" {
  description = "Name of the Backend Prod resource group"
  value       = azurerm_resource_group.backend_prod.name
}

output "public_services_rg_name" {
  description = "Name of the Public Services resource group"
  value       = azurerm_resource_group.public_services.name
}

# =========================================
# NETWORKING OUTPUTS
# =========================================

output "hub_vnet_id" {
  description = "ID of the Hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the Hub VNet"
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Private IP address of Azure Firewall"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "Public IP address of Azure Firewall"
  value       = azurerm_public_ip.firewall.ip_address
}

output "bastion_public_ip" {
  description = "Public IP address of Azure Bastion"
  value       = azurerm_public_ip.bastion.ip_address
}

# =========================================
# VM OUTPUTS
# =========================================

output "backend_dev_vm_private_ip" {
  description = "Private IP of Backend Dev VM"
  value       = azurerm_network_interface.backend_dev_vm.private_ip_address
}

output "backend_test_vm_private_ip" {
  description = "Private IP of Backend Test VM"
  value       = azurerm_network_interface.backend_test_vm.private_ip_address
}

output "backend_prod_vm_private_ip" {
  description = "Private IP of Backend Prod VM"
  value       = azurerm_network_interface.backend_prod_vm.private_ip_address
}

output "listserv_vm_private_ip" {
  description = "Private IP of LISTSERV VM"
  value       = azurerm_network_interface.listserv_vm.private_ip_address
}

# =========================================
# IDENTITY RESOURCES OUTPUTS
# =========================================

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "recovery_services_vault_name" {
  description = "Name of the Recovery Services Vault"
  value       = azurerm_recovery_services_vault.main.name
}

# =========================================
# CONTAINER APP OUTPUTS
# =========================================

output "container_app_environment_id" {
  description = "ID of the Container App Environment"
  value       = azurerm_container_app_environment.main.id
}

output "onepassword_scim_fqdn" {
  description = "FQDN of the 1Password SCIM Container App"
  value       = azurerm_container_app.onepassword_scim.ingress[0].fqdn
}
