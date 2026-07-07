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

output "fabric_dns_zone_names" {
  description = "Fabric/OneLake private-DNS zones created in the hub."
  value       = [for z in azurerm_private_dns_zone.fabric : z.name]
}
