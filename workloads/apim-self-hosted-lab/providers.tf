provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  use_msi         = var.use_msi
  use_cli         = !var.use_msi

  features {}
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  use_msi         = var.use_msi
  use_cli         = !var.use_msi
}