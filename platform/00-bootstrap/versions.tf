terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state backend. Values are supplied via `-backend-config` (never
  # hard-coded here, since the storage account name may be identity-revealing).
  #   terraform init -backend-config=../../_private/backend.hcl
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id_management
  tenant_id       = var.tenant_id
}
