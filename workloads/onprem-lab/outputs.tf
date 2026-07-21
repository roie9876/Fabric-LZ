output "sql_vm_name" {
  value = azurerm_windows_virtual_machine.sql.name
}

output "sql_private_ip" {
  value = azurerm_network_interface.sql.private_ip_address
}

output "opdg_vm_name" {
  value = azurerm_windows_virtual_machine.opdg.name
}

output "opdg_private_ip" {
  value = azurerm_network_interface.opdg.private_ip_address
}

output "onprem_to_hub_peering_id" {
  value = azurerm_virtual_network_peering.onprem_to_hub.id
}

output "onprem_workload_route_table_id" {
  value = azurerm_route_table.workload.id
}

output "sql_database_name" {
  value = "FabricHybridLab"
}

output "sql_login_name" {
  value = "fabric_gateway"
}

output "sql_gateway_password" {
  description = "Sensitive lab-only SQL credential. Retrieve from the private runner only when creating the gateway data source."
  value       = random_password.sql_gateway_login.result
  sensitive   = true
}

output "gateway_registration_required" {
  value = true
}