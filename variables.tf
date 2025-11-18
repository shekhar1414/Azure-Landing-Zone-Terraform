# =========================================
# AUTHENTICATION VARIABLES
# =========================================

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

# =========================================
# GENERAL VARIABLES
# =========================================

variable "environment" {
  description = "Environment name (e.g., nprd, prod)"
  type        = string
  default     = "nprd"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "centralindia"
}

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
  default     = "cin"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "Azure-Landing-Zone"
    Owner       = "shekhar1414"
    ManagedBy   = "Terraform"
    Environment = "Non-Production"
    Repository  = "github.com/shekhar1414/Azure-Landing-Zone-Terraform"
  }
}

# =========================================
# VM VARIABLES
# =========================================

variable "vm_size" {
  description = "Size of the virtual machines"
  type        = string
  default     = "Standard_B2pts_v2"
}

variable "vm_admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}
