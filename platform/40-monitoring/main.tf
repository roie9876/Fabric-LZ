##
# Stage 40 — Monitoring
#
# Centralized observability in the monitor subscription:
#   * Log Analytics workspace
#   * Azure Monitor Private Link Scope (AMPLS)
#   * Data Collection Rules, Action Groups, alerts, workbooks
#
# AMPLS, private DNS, and the central workspace are implemented here. Extend
# this root with DCRs, alert rules, and workbook definitions as needed.
##

variable "subscription_id_monitor" {
  description = "Monitor subscription ID (real value from _private)."
  type        = string
}

variable "subscription_id_connectivity" {
  description = "Connectivity subscription containing the hub VNet and AMPLS private endpoint subnet."
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

variable "subcode_connectivity" {
  type    = string
  default = "0000"
}

variable "azure_monitor_blob_private_dns_zone_resource_group_name" {
  description = "Resource group of an existing hub-linked privatelink.blob.core.windows.net zone. Leave null to create and link the zone in the connectivity resource group."
  type        = string
  default     = null
}

locals {
  tags = {
    layer   = "platform"
    stage   = "40-monitoring"
    managed = "terraform"
  }

  azure_monitor_private_dns_zones = toset([
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
  ])
}

data "azurerm_resource_group" "connectivity" {
  provider = azurerm.connectivity
  name     = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-rg-net-hub"
}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.connectivity
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-vnet-hub-core"
  resource_group_name = data.azurerm_resource_group.connectivity.name
}

data "azurerm_subnet" "monitor_private_endpoint" {
  provider             = azurerm.connectivity
  name                 = "AzureMonitorPrivateEndpointSubnet"
  virtual_network_name = data.azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.connectivity.name
}

resource "azurerm_resource_group" "monitor" {
  name     = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "central" {
  name                            = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.monitor.name
  sku                             = "PerGB2018"
  retention_in_days               = 90
  internet_ingestion_enabled      = false
  internet_query_enabled          = false
  allow_resource_only_permissions = true
  local_authentication_enabled    = false
  tags                            = local.tags
}

resource "azurerm_monitor_private_link_scope" "central" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_monitor}-ampls-central"
  resource_group_name = azurerm_resource_group.monitor.name

  ingestion_access_mode = "PrivateOnly"
  query_access_mode     = "PrivateOnly"
  tags                  = local.tags
}

resource "azurerm_monitor_private_link_scoped_service" "central_workspace" {
  name                = "central-log-analytics"
  resource_group_name = azurerm_resource_group.monitor.name
  scope_name          = azurerm_monitor_private_link_scope.central.name
  linked_resource_id  = azurerm_log_analytics_workspace.central.id
}

resource "azurerm_private_dns_zone" "azure_monitor" {
  provider            = azurerm.connectivity
  for_each            = local.azure_monitor_private_dns_zones
  name                = each.value
  resource_group_name = data.azurerm_resource_group.connectivity.name
  tags                = local.tags
}

data "azurerm_private_dns_zone" "existing_blob" {
  provider            = azurerm.connectivity
  count               = var.azure_monitor_blob_private_dns_zone_resource_group_name == null ? 0 : 1
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.azure_monitor_blob_private_dns_zone_resource_group_name
}

resource "azurerm_private_dns_zone" "azure_monitor_blob" {
  provider            = azurerm.connectivity
  count               = var.azure_monitor_blob_private_dns_zone_resource_group_name == null ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.connectivity.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "azure_monitor_hub" {
  provider              = azurerm.connectivity
  for_each              = azurerm_private_dns_zone.azure_monitor
  name                  = "hub-link"
  resource_group_name   = data.azurerm_resource_group.connectivity.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "azure_monitor_blob_hub" {
  provider              = azurerm.connectivity
  count                 = var.azure_monitor_blob_private_dns_zone_resource_group_name == null ? 1 : 0
  name                  = "hub-link"
  resource_group_name   = data.azurerm_resource_group.connectivity.name
  private_dns_zone_name = azurerm_private_dns_zone.azure_monitor_blob[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}

locals {
  azure_monitor_blob_private_dns_zone_id = var.azure_monitor_blob_private_dns_zone_resource_group_name == null ? azurerm_private_dns_zone.azure_monitor_blob[0].id : data.azurerm_private_dns_zone.existing_blob[0].id
  azure_monitor_private_dns_zone_ids     = concat([for zone in azurerm_private_dns_zone.azure_monitor : zone.id], [local.azure_monitor_blob_private_dns_zone_id])
}

resource "azurerm_private_endpoint" "azure_monitor" {
  provider            = azurerm.connectivity
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-pe-ampls-central"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.connectivity.name
  subnet_id           = data.azurerm_subnet.monitor_private_endpoint.id
  tags                = local.tags

  private_service_connection {
    name                           = "azuremonitor"
    private_connection_resource_id = azurerm_monitor_private_link_scope.central.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "azure-monitor-private-dns"
    private_dns_zone_ids = local.azure_monitor_private_dns_zone_ids
  }

  depends_on = [
    azurerm_monitor_private_link_scoped_service.central_workspace,
    azurerm_private_dns_zone_virtual_network_link.azure_monitor_hub,
    azurerm_private_dns_zone_virtual_network_link.azure_monitor_blob_hub,
  ]
}
