locals {
  prefix = "azr-${var.env}-${var.org}-${var.subcode_foundry}"

  foundry_resource_group_name = "${local.prefix}-rg-foundry"
  foundry_vnet_name           = "${local.prefix}-vnet-foundry"
  foundry_app_insights_name   = "${local.prefix}-appi-foundry"

  hub_resource_group_name = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-rg-net-hub"
  hub_firewall_name       = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-fw-hub"

  monitor_resource_group_name = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  monitor_workspace_name      = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"

  tags = {
    layer   = "platform"
    stage   = "35-ai-gateway"
    managed = "terraform"
  }
}

resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  upper       = false
}

data "azurerm_resource_group" "foundry" {
  name = local.foundry_resource_group_name
}

data "azurerm_virtual_network" "foundry" {
  name                = local.foundry_vnet_name
  resource_group_name = data.azurerm_resource_group.foundry.name
}

data "azurerm_subnet" "private_endpoints" {
  name                 = "pe-subnet"
  resource_group_name  = data.azurerm_resource_group.foundry.name
  virtual_network_name = data.azurerm_virtual_network.foundry.name
}

data "azurerm_firewall" "hub" {
  provider            = azurerm.connectivity
  name                = local.hub_firewall_name
  resource_group_name = local.hub_resource_group_name
}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.connectivity
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-vnet-hub-core"
  resource_group_name = local.hub_resource_group_name
}

data "azurerm_log_analytics_workspace" "central" {
  provider            = azurerm.monitoring
  name                = local.monitor_workspace_name
  resource_group_name = local.monitor_resource_group_name
}

data "azurerm_application_insights" "foundry" {
  name                = local.foundry_app_insights_name
  resource_group_name = data.azurerm_resource_group.foundry.name
}

resource "azurerm_network_security_group" "integration" {
  name                = "${local.prefix}-nsg-apim-integration"
  location            = var.foundry_location
  resource_group_name = data.azurerm_resource_group.foundry.name
  tags                = local.tags

  security_rule {
    name                       = "AllowStorageHttps"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "Storage"
  }

  security_rule {
    name                       = "AllowKeyVaultHttps"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureKeyVault"
  }

  security_rule {
    name                       = "AllowEntraHttps"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AzureActiveDirectory"
  }

  security_rule {
    name                       = "AllowPrivateBackendsHttps"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet" "integration" {
  name                            = "apim-integration-subnet"
  resource_group_name             = data.azurerm_resource_group.foundry.name
  virtual_network_name            = data.azurerm_virtual_network.foundry.name
  address_prefixes                = [var.apim_integration_subnet_prefix]
  default_outbound_access_enabled = false

  delegation {
    name = "Microsoft.Web/serverFarms"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "integration" {
  subnet_id                 = azurerm_subnet.integration.id
  network_security_group_id = azurerm_network_security_group.integration.id
}

resource "azurerm_route_table" "integration" {
  name                          = "${local.prefix}-rt-apim-integration"
  location                      = var.foundry_location
  resource_group_name           = data.azurerm_resource_group.foundry.name
  bgp_route_propagation_enabled = true
  tags                          = local.tags
}

resource "azurerm_route" "default_to_hub_firewall" {
  name                   = "default-to-hub-firewall"
  resource_group_name    = data.azurerm_resource_group.foundry.name
  route_table_name       = azurerm_route_table.integration.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "integration" {
  subnet_id      = azurerm_subnet.integration.id
  route_table_id = azurerm_route_table.integration.id
}

resource "azurerm_api_management" "ai_gateway" {
  name                          = substr(lower(replace("${local.prefix}-apim-${random_string.unique.result}", "_", "-")), 0, 50)
  location                      = var.foundry_location
  resource_group_name           = data.azurerm_resource_group.foundry.name
  publisher_name                = var.apim_publisher_name
  publisher_email               = var.apim_publisher_email
  sku_name                      = "StandardV2_1"
  public_network_access_enabled = var.apim_public_network_access_enabled
  virtual_network_type          = "External"
  tags                          = local.tags

  identity {
    type = "SystemAssigned"
  }

  virtual_network_configuration {
    subnet_id = azurerm_subnet.integration.id
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.integration,
    azurerm_subnet_route_table_association.integration,
  ]
}

resource "azurerm_private_dns_zone" "apim" {
  provider            = azurerm.connectivity
  name                = "privatelink.azure-api.net"
  resource_group_name = local.hub_resource_group_name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim_hub" {
  provider              = azurerm.connectivity
  name                  = "hub-link"
  resource_group_name   = local.hub_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.apim.name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim_foundry" {
  provider              = azurerm.connectivity
  name                  = "foundry-spoke-link"
  resource_group_name   = local.hub_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.apim.name
  virtual_network_id    = data.azurerm_virtual_network.foundry.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "apim" {
  name                = "${local.prefix}-pe-apim-gateway"
  location            = var.foundry_location
  resource_group_name = data.azurerm_resource_group.foundry.name
  subnet_id           = data.azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "apim-gateway"
    private_connection_resource_id = azurerm_api_management.ai_gateway.id
    subresource_names              = ["Gateway"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "apim-private-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.apim.id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_api_management.ai_gateway.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_role_assignment" "apim_monitoring_metrics_publisher" {
  scope                = data.azurerm_application_insights.foundry.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_api_management.ai_gateway.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_api_management_logger" "application_insights" {
  name                = "foundry-application-insights"
  api_management_name = azurerm_api_management.ai_gateway.name
  resource_group_name = data.azurerm_resource_group.foundry.name
  resource_id         = data.azurerm_application_insights.foundry.id

  application_insights {
    connection_string  = data.azurerm_application_insights.foundry.connection_string
    identity_client_id = "SystemAssigned"
  }

  depends_on = [azurerm_role_assignment.apim_monitoring_metrics_publisher]
}