output "workspace_private_link_service_id" {
  description = "Azure resource ID of the Fabric workspace Private Link service."
  value       = azapi_resource.workspace_private_link.id
}

output "workspace_private_endpoint_id" {
  description = "Azure resource ID of the Fabric workspace private endpoint."
  value       = azurerm_private_endpoint.workspace.id
}

output "workspace_private_endpoint_ips" {
  description = "Private IP addresses allocated to the Fabric workspace endpoint."
  value = sort([
    for config in data.azurerm_network_interface.workspace.ip_configuration : config.private_ip_address
  ])
}

output "workspace_api_fqdn" {
  description = "Workspace-specific Fabric API FQDN used for private connectivity tests."
  value = format(
    "%s.z%s.w.api.fabric.microsoft.com",
    replace(lower(var.fabric_private_workspace_id), "-", ""),
    substr(lower(var.fabric_private_workspace_id), 0, 2)
  )
}