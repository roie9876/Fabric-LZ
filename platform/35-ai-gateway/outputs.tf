output "api_management_id" {
  value = azurerm_api_management.ai_gateway.id
}

output "api_management_name" {
  value = azurerm_api_management.ai_gateway.name
}

output "api_management_private_endpoint_id" {
  value = azurerm_private_endpoint.apim.id
}

output "api_management_principal_id" {
  value = azurerm_api_management.ai_gateway.identity[0].principal_id
}