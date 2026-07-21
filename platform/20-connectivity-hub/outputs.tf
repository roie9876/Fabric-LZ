output "hub_vnet_id" {
  description = "Resource ID of the hub VNet (consumed by spokes)."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "monitor_private_endpoint_subnet_id" {
  description = "Dedicated /27 hub subnet for the central Azure Monitor Private Link Scope endpoint."
  value       = azurerm_subnet.monitor_private_endpoint.id
}

output "firewall_private_ip" {
  description = "Hub Azure Firewall private IP — spokes route 0.0.0.0/0 here."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_policy_id" {
  value = azurerm_firewall_policy.hub.id
}

output "dns_inbound_endpoint_ip" {
  description = "Private DNS Resolver inbound endpoint IP (for on-prem conditional forwarding)."
  value       = azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address
}
