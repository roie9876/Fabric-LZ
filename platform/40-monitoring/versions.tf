terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    key = "40-monitoring.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id_monitor
  tenant_id       = var.tenant_id
}

provider "azurerm" {
  alias = "connectivity"
  features {}
  subscription_id = var.subscription_id_connectivity
  tenant_id       = var.tenant_id
}
