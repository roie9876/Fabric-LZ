output "log_analytics_workspace_id" {
  description = "Resource ID of the central private Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.central.id
}

output "azure_monitor_private_link_scope_id" {
  description = "Central AMPLS ID for workload Application Insights and DCE associations."
  value       = azurerm_monitor_private_link_scope.central.id
}

output "azure_monitor_private_endpoint_id" {
  description = "Hub private endpoint used for Azure Monitor ingestion and queries."
  value       = azurerm_private_endpoint.azure_monitor.id
}

output "azure_monitor_private_dns_zone_ids" {
  description = "Central Azure Monitor private DNS zone IDs."
  value = merge(
    { for name, zone in azurerm_private_dns_zone.azure_monitor : name => zone.id },
    { "privatelink.blob.core.windows.net" = local.azure_monitor_blob_private_dns_zone_id }
  )
}