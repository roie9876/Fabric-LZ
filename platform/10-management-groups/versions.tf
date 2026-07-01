terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  tenant_id = var.tenant_id
}

variable "tenant_id" {
  description = "Entra tenant ID (real value from _private)."
  type        = string
}
