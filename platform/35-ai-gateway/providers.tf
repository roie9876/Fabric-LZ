provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id_workloads
  tenant_id           = var.tenant_id
  storage_use_azuread = true
  use_msi             = true
}

provider "azurerm" {
  alias = "connectivity"
  features {}
  subscription_id     = var.subscription_id_connectivity
  tenant_id           = var.tenant_id
  storage_use_azuread = true
  use_msi             = true
}

provider "azurerm" {
  alias = "monitoring"
  features {}
  subscription_id     = var.subscription_id_monitor
  tenant_id           = var.tenant_id
  storage_use_azuread = true
  use_msi             = true
}