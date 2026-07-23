provider "azurerm" {
  subscription_id = var.subscription_id_workloads
  tenant_id       = var.tenant_id
  use_cli         = !var.use_msi
  use_msi         = var.use_msi

  features {}
}