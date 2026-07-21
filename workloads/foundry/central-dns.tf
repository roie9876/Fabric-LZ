locals {
  central_foundry_dns_zones = local.create_dns_zones ? {
    "privatelink.documents.azure.com"         = azurerm_private_dns_zone.plz_cosmos_db[0].name
    "privatelink.search.windows.net"          = azurerm_private_dns_zone.plz_ai_search[0].name
    "privatelink.cognitiveservices.azure.com" = azurerm_private_dns_zone.plz_cognitive_services[0].name
    "privatelink.services.ai.azure.com"       = azurerm_private_dns_zone.plz_ai_services[0].name
    "privatelink.openai.azure.com"            = azurerm_private_dns_zone.plz_openai[0].name
  } : {}
}

resource "azurerm_private_dns_zone_virtual_network_link" "foundry_zones_hub" {
  provider              = azurerm.connectivity
  for_each              = local.central_foundry_dns_zones
  name                  = "hub-link"
  resource_group_name   = local.hub_resource_group_name
  private_dns_zone_name = each.value
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "created_blob_hub" {
  provider              = azurerm.connectivity
  count                 = local.create_dns_zones && var.existing_blob_private_dns_zone_resource_group_name == null ? 1 : 0
  name                  = "hub-link"
  resource_group_name   = local.hub_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.plz_storage_blob[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "existing_blob_foundry" {
  provider              = azurerm.connectivity
  count                 = var.existing_blob_private_dns_zone_resource_group_name == null ? 0 : 1
  name                  = "foundry-spoke-link"
  resource_group_name   = var.existing_blob_private_dns_zone_resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.existing_blob[0].name
  virtual_network_id    = local.vnet_id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_hub" {
  provider              = azurerm.connectivity
  count                 = var.enable_container_registry && local.create_dns_zones ? 1 : 0
  name                  = "hub-link"
  resource_group_name   = local.hub_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.plz_acr[0].name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}