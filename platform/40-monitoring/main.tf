##
# Stage 40 — Monitoring
#
# Centralized observability in the monitor subscription:
#   * Log Analytics workspace
#   * Azure Monitor Private Link Scope (AMPLS)
#   * Data Collection Rules, Action Groups, alerts, workbooks
#
# Starter skeleton — extend with DCRs, alert rules, and workbook definitions.
##

variable "subscription_id_monitor" {
  description = "Monitor subscription ID (real value from _private)."
  type        = string
}

variable "tenant_id" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "org" {
  type    = string
  default = "org"
}

variable "env" {
  type    = string
  default = "prd"
}

variable "subcode_monitor" {
  type    = string
  default = "0000"
}

resource "azurerm_resource_group" "monitor" {
  name     = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  location = var.location
  tags = {
    layer = "platform"
    stage = "40-monitoring"
  }
}

resource "azurerm_log_analytics_workspace" "central" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"
  location            = var.location
  resource_group_name = azurerm_resource_group.monitor.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
}
