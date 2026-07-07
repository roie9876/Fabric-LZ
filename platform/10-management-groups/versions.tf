terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    key = "10-management-groups.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id_management
  tenant_id       = var.tenant_id
}

variable "subscription_id_management" {
  description = "Management subscription ID (satisfies azurerm v4 provider auth; MG ops are tenant-scoped)."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID (real value from _private)."
  type        = string
}
