##
# Workload — Fabric workspace Private Link (Layer 2, Phase B)
#
# Run only after both Fabric workspaces exist, are assigned to the F capacity,
# and the private workspace ID has been added to the private tfvars file.
##

locals {
  tags = {
    layer   = "workload"
    stage   = "fabric-private-link"
    managed = "terraform"
  }

  hub_rg                     = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-rg-net-hub"
  spoke_rg                   = "azr-${var.env}-${var.org}-${var.subcode_fabric}-rg-fabric-spoke"
  spoke_vnet                 = "azr-${var.env}-${var.org}-${var.subcode_fabric}-vnet-fabric-spoke"
  workspace_private_dns_zone = "privatelink.fabric.microsoft.com"
  workspace_pls              = "azr-${var.env}-${var.org}-${var.subcode_fabric}-fabpls-private"
  workspace_pe               = "azr-${var.env}-${var.org}-${var.subcode_fabric}-pe-fabric-private"
}

data "azurerm_resource_group" "fabric" {
  name = local.spoke_rg
}

data "azurerm_subnet" "private_endpoints" {
  name                 = "pe-subnet"
  resource_group_name  = local.spoke_rg
  virtual_network_name = local.spoke_vnet
}

data "azurerm_private_dns_zone" "workspace" {
  name                = local.workspace_private_dns_zone
  resource_group_name = local.hub_rg
}

resource "azapi_resource" "workspace_private_link" {
  type                      = "Microsoft.Fabric/privateLinkServicesForFabric@2024-06-01"
  name                      = local.workspace_pls
  parent_id                 = data.azurerm_resource_group.fabric.id
  location                  = "global"
  schema_validation_enabled = false

  body = {
    properties = {
      tenantId    = var.tenant_id
      workspaceId = var.fabric_private_workspace_id
    }
  }

  tags = local.tags
}

resource "azurerm_private_endpoint" "workspace" {
  name                = local.workspace_pe
  location            = var.location
  resource_group_name = data.azurerm_resource_group.fabric.name
  subnet_id           = data.azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "workspace-private-link"
    private_connection_resource_id = azapi_resource.workspace_private_link.id
    is_manual_connection           = false
    subresource_names              = ["workspace"]
  }

  private_dns_zone_group {
    name                 = "workspace-private-dns"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.workspace.id]
  }
}

data "azurerm_network_interface" "workspace" {
  name                = azurerm_private_endpoint.workspace.network_interface[0].name
  resource_group_name = data.azurerm_resource_group.fabric.name
}