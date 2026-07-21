output "resource_group_name" {
  description = "The name of the resource group"
  value       = local.rg_name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = local.vnet_id
}

output "ai_foundry_id" {
  description = "The ID of the AI Foundry account"
  value       = azapi_resource.ai_foundry.id
}

output "ai_foundry_name" {
  description = "Foundry account name."
  value       = azapi_resource.ai_foundry.name
}

output "ai_foundry_project_id" {
  description = "Foundry project ARM resource ID."
  value       = azapi_resource.ai_project.id
}

output "ai_foundry_project_endpoint" {
  description = "Foundry project data-plane endpoint."
  value       = "https://${azapi_resource.ai_foundry.name}.services.ai.azure.com/api/projects/${azapi_resource.ai_project.name}"
}

output "model_deployment_name" {
  value = azapi_resource.model_deployment.name
}

output "agent_subnet_id" {
  value = local.subnet_agent_id
}

output "private_endpoint_subnet_id" {
  value = local.subnet_pe_id
}

output "tools_subnet_id" {
  value = local.subnet_mcp_id
}

output "container_registry_id" {
  value = var.enable_container_registry ? azurerm_container_registry.acr[0].id : null
}

output "container_registry_login_server" {
  value = var.enable_container_registry ? azurerm_container_registry.acr[0].login_server : null
}

output "storage_account_id" {
  description = "The ID of the storage account"
  value       = local.storage_id
}

output "search_service_id" {
  description = "The ID of the AI Search service"
  value       = local.search_id
}

output "cosmos_db_id" {
  description = "The ID of the Cosmos DB account"
  value       = local.cosmos_id
}

output "application_insights_id" {
  description = "Private workspace-based Application Insights component associated with central AMPLS."
  value       = azurerm_application_insights.foundry.id
}

output "application_insights_connection_string" {
  description = "Connection string used by the hosted agent OpenTelemetry exporter."
  value       = azurerm_application_insights.foundry.connection_string
  sensitive   = true
}
