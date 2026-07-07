terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Shared remote-state backend (same container as the platform stages).
  #   terraform init -backend-config=../../_private/backend.hcl
  backend "azurerm" {
    key = "workloads-fabric.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id_workloads
  tenant_id           = var.tenant_id
  storage_use_azuread = true
}
