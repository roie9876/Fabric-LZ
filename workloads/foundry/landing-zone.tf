data "azurerm_virtual_network" "hub" {
  provider            = azurerm.connectivity
  name                = local.hub_vnet_name
  resource_group_name = local.hub_resource_group_name
}

data "azurerm_firewall" "hub" {
  provider            = azurerm.connectivity
  name                = local.hub_firewall_name
  resource_group_name = local.hub_resource_group_name
}

resource "azurerm_virtual_network_peering" "foundry_to_hub" {
  name                         = "foundry-to-hub"
  resource_group_name          = local.rg_name
  virtual_network_name         = local.vnet_name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_foundry" {
  provider                     = azurerm.connectivity
  name                         = "hub-to-foundry"
  resource_group_name          = local.hub_resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.hub.name
  remote_virtual_network_id    = local.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_route_table" "foundry" {
  name                          = "${local.prefix}-rt-foundry"
  location                      = var.foundry_location
  resource_group_name           = local.rg_name
  bgp_route_propagation_enabled = true
  tags                          = local.tags
}

resource "azurerm_route" "default_to_hub_firewall" {
  name                   = "default-to-hub-firewall"
  resource_group_name    = local.rg_name
  route_table_name       = azurerm_route_table.foundry.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "agent" {
  subnet_id      = local.subnet_agent_id
  route_table_id = azurerm_route_table.foundry.id
}

resource "azurerm_subnet_route_table_association" "mcp" {
  subnet_id      = local.subnet_mcp_id
  route_table_id = azurerm_route_table.foundry.id
}