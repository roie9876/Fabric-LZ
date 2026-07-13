output "fabric_spoke_vnet_id" {
  description = "Resource ID of the Fabric spoke VNet."
  value       = azurerm_virtual_network.spoke.id
}

output "pe_subnet_id" {
  description = "Private-endpoint subnet ID (host the Fabric workspace private endpoint here)."
  value       = azurerm_subnet.pe.id
}

output "fabric_capacity_id" {
  description = "Resource ID of the Microsoft Fabric capacity."
  value       = azurerm_fabric_capacity.this.id
}

output "fabric_capacity_name" {
  value = azurerm_fabric_capacity.this.name
}

output "workspace_private_dns_zone_id" {
  description = "Private DNS zone used by Fabric workspace-level Private Link."
  value       = azurerm_private_dns_zone.workspace.id
}

output "workspace_private_dns_zone_name" {
  description = "Private DNS zone used by Fabric workspace-level Private Link."
  value       = azurerm_private_dns_zone.workspace.name
}
