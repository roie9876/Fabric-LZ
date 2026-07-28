output "api_management_id" {
  value = azurerm_api_management.lab.id
}

output "api_management_name" {
  value = azurerm_api_management.lab.name
}

output "gateway_id" {
  value = azapi_resource.runner_gateway.id
}

output "gateway_name" {
  value = var.gateway_name
}

output "configuration_endpoint" {
  description = "Self-hosted gateway configuration endpoint; not a runtime API URL."
  value       = "https://${var.api_management_name}.configuration.azure-api.net"
}

output "private_validation_url" {
  value = "http://172.16.1.5:9080/runner-echo"
}