##
# Workload — Fabric spoke (Layer 2)
#
# Builds the Fabric spoke network foundation and a Fabric capacity, wired into
# the Layer 1 hub:
#   * Spoke VNet + pe-subnet, peered to the hub (classic peering)
#   * UDR 0.0.0.0/0 -> hub Azure Firewall (forced tunnel)
#   * Workspace-level Private Link DNS zone linked to hub + spoke
#   * Microsoft Fabric capacity (F-SKU)
#   * Diagnostics -> central Log Analytics
#
# Workspace creation is a Fabric control-plane step. The workspace-level Private
# Link service and private endpoint are deployed afterward from
# workloads/fabric-private-link, once the private workspace ID is known.
##

locals {
  tags = {
    layer   = "workload"
    stage   = "fabric"
    managed = "terraform"
  }

  hub_rg      = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-rg-net-hub"
  hub_vnet    = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-vnet-hub-core"
  hub_fw      = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-fw-hub"
  monitor_rg  = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  monitor_law = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"
  spoke_rg    = "azr-${var.env}-${var.org}-${var.subcode_fabric}-rg-fabric-spoke"
  spoke_vnet  = "azr-${var.env}-${var.org}-${var.subcode_fabric}-vnet-fabric-spoke"
  spoke_rt    = "azr-${var.env}-${var.org}-${var.subcode_fabric}-rt-fabric-spoke"
  capacity    = lower("azr${var.env}${var.org}${var.subcode_fabric}fabcap")

  workspace_private_dns_zone = "privatelink.fabric.microsoft.com"
}

# ---------- Look up Layer 1 resources (deterministic names) ----------
data "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet
  resource_group_name = local.hub_rg
}

data "azurerm_firewall" "hub" {
  name                = local.hub_fw
  resource_group_name = local.hub_rg
}

data "azurerm_log_analytics_workspace" "central" {
  name                = local.monitor_law
  resource_group_name = local.monitor_rg
}

# ---------- Fabric spoke VNet ----------
resource "azurerm_resource_group" "fabric" {
  name     = local.spoke_rg
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = local.spoke_vnet
  location            = var.location
  resource_group_name = azurerm_resource_group.fabric.name
  address_space       = [var.fabric_spoke_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "pe" {
  name                              = "pe-subnet"
  resource_group_name               = azurerm_resource_group.fabric.name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [var.fabric_pe_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
  default_outbound_access_enabled   = false
}

# ---------- Forced-tunnel route table (0.0.0.0/0 -> hub firewall) ----------
resource "azurerm_route_table" "spoke" {
  name                = local.spoke_rt
  location            = var.location
  resource_group_name = azurerm_resource_group.fabric.name
  tags                = local.tags
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "to-firewall"
  resource_group_name    = azurerm_resource_group.fabric.name
  route_table_name       = azurerm_route_table.spoke.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

# Return-path route: PE -> on-prem traffic goes back through the hub firewall.
# On-prem is peered with the hub (not the spoke), and VNet peering is not
# transitive, so the spoke reaches on-prem via the firewall transit. This explicit
# route sends the on-prem prefix to the firewall, keeping inspection symmetric.
resource "azurerm_route" "onprem_return_to_firewall" {
  count                  = var.force_onprem_return_via_firewall ? 1 : 0
  name                   = "onprem-to-firewall"
  resource_group_name    = azurerm_resource_group.fabric.name
  route_table_name       = azurerm_route_table.spoke.name
  address_prefix         = var.onprem_source_cidr
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "pe" {
  subnet_id      = azurerm_subnet.pe.id
  route_table_id = azurerm_route_table.spoke.id
}

# ---------- Hub <-> spoke peering (firewall transit) ----------
# The simulated on-prem VNet peers directly with the hub, and the hub firewall
# transits on-prem <-> spoke traffic. The spoke reaches on-prem through the
# pe-subnet route 172.16.0.0/16 -> firewall and the hub through peering.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "fabric-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.fabric.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-fabric-spoke"
  resource_group_name          = local.hub_rg
  virtual_network_name         = local.hub_vnet
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# ---------- Workspace-level Private Link DNS (linked to hub + spoke) ----------
resource "azurerm_private_dns_zone" "workspace" {
  name                = local.workspace_private_dns_zone
  resource_group_name = local.hub_rg
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "workspace_spoke" {
  name                  = "link-fabric-spoke"
  resource_group_name   = local.hub_rg
  private_dns_zone_name = azurerm_private_dns_zone.workspace.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "workspace_hub" {
  name                  = "link-hub"
  resource_group_name   = local.hub_rg
  private_dns_zone_name = azurerm_private_dns_zone.workspace.name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
}

# ---------- Microsoft Fabric capacity ----------
resource "azurerm_fabric_capacity" "this" {
  name                = local.capacity
  resource_group_name = azurerm_resource_group.fabric.name
  location            = var.location

  administration_members = [var.fabric_admin_upn]

  sku {
    name = var.fabric_capacity_sku
    tier = "Fabric"
  }

  tags = local.tags
}

# ---------- Diagnostics: spoke VNet -> central Log Analytics ----------
resource "azurerm_monitor_diagnostic_setting" "spoke_vnet" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_virtual_network.spoke.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id

  enabled_metric {
    category = "AllMetrics"
  }
}
