##
# Stage 20 — Connectivity Hub
#
# Central Hub & Spoke networking foundation:
#   * Hub VNet with the standard subnets (Firewall, Gateway, DNS Resolver, SWG)
#   * Azure Firewall + Firewall Policy (central inspection point)
#   * DDoS Protection plan (optional)
#   * Private DNS Resolver (inbound + outbound)
#   * Azure Virtual Network Manager (AVNM) for Hub & Spoke connectivity
#
# Starter skeleton — extend with ExpressRoute Gateway, firewall rule
# collections, and AVNM connectivity/security configurations as needed.
##

# ---------- Naming ----------
module "net_rg_name" {
  source  = "../../modules/naming"
  env     = var.env
  org     = var.org
  subcode = var.subcode_connectivity
  type    = "rg"
  role    = "net-hub"
}

module "fw_rg_name" {
  source  = "../../modules/naming"
  env     = var.env
  org     = var.org
  subcode = var.subcode_connectivity
  type    = "rg"
  role    = "fw-hub"
}

module "hub_vnet_name" {
  source  = "../../modules/naming"
  env     = var.env
  org     = var.org
  subcode = var.subcode_connectivity
  type    = "vnet"
  role    = "hub-core"
}

# ---------- Resource groups ----------
resource "azurerm_resource_group" "net" {
  name     = module.net_rg_name.name
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "fw" {
  name     = module.fw_rg_name.name
  location = var.location
  tags     = local.tags
}

locals {
  tags = {
    layer   = "platform"
    stage   = "20-connectivity-hub"
    managed = "terraform"
  }
}

# ---------- Hub VNet + subnets ----------
resource "azurerm_virtual_network" "hub" {
  name                = module.hub_vnet_name.name
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  address_space       = [var.hub_vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet" # fixed name required by Azure
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_prefixes.firewall]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # fixed name required by Azure
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_prefixes.gateway]
}

resource "azurerm_subnet" "dns_inbound" {
  name                 = "DNSInboundResolverSubnet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_prefixes.dns_inbound]

  delegation {
    name = "dns-resolver"
    service_delegation {
      name = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "dns_outbound" {
  name                 = "DNSOutboundResolverSubnet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_prefixes.dns_outbound]

  delegation {
    name = "dns-resolver"
    service_delegation {
      name = "Microsoft.Network/dnsResolvers"
    }
  }
}

resource "azurerm_subnet" "egress_swg" {
  name                 = "EgressSwgSubnet"
  resource_group_name  = azurerm_resource_group.net.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.subnet_prefixes.egress_swg]
}

# ---------- DDoS Protection ----------
resource "azurerm_network_ddos_protection_plan" "hub" {
  count               = var.enable_ddos ? 1 : 0
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-ddos-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags
}

# ---------- Azure Firewall ----------
resource "azurerm_firewall_policy" "hub" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-fwpol-hub"
  resource_group_name = azurerm_resource_group.fw.name
  location            = var.location
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_public_ip" "fw" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-pip-fw-hub"
  resource_group_name = azurerm_resource_group.fw.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_firewall" "hub" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-fw-hub"
  # Azure Firewall must reside in the SAME resource group as the VNet/subnet it
  # references (AzureFirewallSubnet lives in the net RG), so deploy it there.
  # The public IP and firewall policy may remain in the fw RG.
  resource_group_name = azurerm_resource_group.net.name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.fw.id
  }

  tags = local.tags
}

# ---------- Private DNS Resolver ----------
resource "azurerm_private_dns_resolver" "hub" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-dnsres-hub"
  resource_group_name = azurerm_resource_group.net.name
  location            = var.location
  virtual_network_id  = azurerm_virtual_network.hub.id
  tags                = local.tags
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  name                    = "inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  location                = var.location

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.dns_inbound.id
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "hub" {
  name                    = "outbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  location                = var.location
  subnet_id               = azurerm_subnet.dns_outbound.id
}

# ---------- Azure Virtual Network Manager (Hub & Spoke) ----------
data "azurerm_subscription" "current" {}

resource "azurerm_network_manager" "hub" {
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-avnm-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  scope_accesses      = ["Connectivity", "SecurityAdmin"]

  scope {
    subscription_ids = [data.azurerm_subscription.current.id]
  }

  tags = local.tags
}

resource "azurerm_network_manager_network_group" "spokes" {
  name               = "spokes"
  network_manager_id = azurerm_network_manager.hub.id
  description        = "All workload spoke VNets (Fabric, Foundry, ...)."
}
