locals {
  monitor_resource_group_name = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  monitor_workspace_name      = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"
  monitor_ampls_name          = "azr-${var.env}-${var.org}-${var.subcode_monitor}-ampls-central"

  azure_monitor_private_dns_zone_names = toset([
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
  ])
}

data "azurerm_log_analytics_workspace" "central" {
  provider            = azurerm.monitoring
  name                = local.monitor_workspace_name
  resource_group_name = local.monitor_resource_group_name
}

data "azurerm_private_dns_zone" "azure_monitor" {
  provider            = azurerm.connectivity
  for_each            = local.azure_monitor_private_dns_zone_names
  name                = each.value
  resource_group_name = local.hub_resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "azure_monitor_foundry" {
  provider              = azurerm.connectivity
  for_each              = data.azurerm_private_dns_zone.azure_monitor
  name                  = "foundry-spoke-link"
  resource_group_name   = local.hub_resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = local.vnet_id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_application_insights" "foundry" {
  name                         = "${local.prefix}-appi-foundry"
  location                     = var.foundry_location
  resource_group_name          = local.rg_name
  application_type             = "web"
  workspace_id                 = data.azurerm_log_analytics_workspace.central.id
  internet_ingestion_enabled   = false
  internet_query_enabled       = false
  local_authentication_enabled = false
  retention_in_days            = 90
  tags                         = local.tags
}

resource "azurerm_monitor_private_link_scoped_service" "foundry_application_insights" {
  provider            = azurerm.monitoring
  name                = "foundry-application-insights"
  resource_group_name = local.monitor_resource_group_name
  scope_name          = local.monitor_ampls_name
  linked_resource_id  = azurerm_application_insights.foundry.id
}

resource "azurerm_role_assignment" "project_application_insights_reader" {
  name                 = uuidv5("dns", "${azapi_resource.ai_project.name}${azapi_resource.ai_project.output.identity.principalId}applicationinsightsreader")
  scope                = azurerm_application_insights.foundry.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azapi_resource.ai_project.output.identity.principalId

  depends_on = [time_sleep.wait_project_identities]
}

resource "azurerm_role_assignment" "project_log_analytics_reader" {
  provider             = azurerm.monitoring
  name                 = uuidv5("dns", "${azapi_resource.ai_project.name}${azapi_resource.ai_project.output.identity.principalId}loganalyticsreader")
  scope                = data.azurerm_log_analytics_workspace.central.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azapi_resource.ai_project.output.identity.principalId

  depends_on = [time_sleep.wait_project_identities]
}
