terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    key = "workloads-fabric-private-link.tfstate"
  }
}

provider "azapi" {
  subscription_id = var.subscription_id_workloads
  tenant_id       = var.tenant_id
  use_msi         = true
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id_workloads
  tenant_id           = var.tenant_id
  storage_use_azuread = true
  use_msi             = true
}