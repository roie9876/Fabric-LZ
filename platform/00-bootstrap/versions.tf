terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state backend. Connection values (RG / storage account / container /
  # use_azuread_auth) are supplied via `-backend-config`, never hard-coded here:
  #   terraform init -backend-config=../../_private/backend.hcl
  # Only the per-stage state file name (`key`) lives in code, so each stage
  # writes to its own blob inside the shared container.
  backend "azurerm" {
    key = "00-bootstrap.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id_management
  tenant_id       = var.tenant_id

  # Use Azure AD (the logged-in identity) for Storage data-plane operations
  # instead of account keys. Required when shared-key auth is disabled by policy.
  storage_use_azuread = true
}
