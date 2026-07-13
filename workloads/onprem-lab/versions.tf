terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    key = "workloads-onprem-lab.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id_workloads
  tenant_id           = var.tenant_id
  storage_use_azuread = true
  use_msi             = true
}