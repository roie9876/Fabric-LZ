output "external_agent_name" {
  value = azurerm_container_app.external_agent.name
}

output "external_agent_private_fqdn" {
  value = azurerm_container_app.external_agent.ingress[0].fqdn
}

output "external_agent_principal_id" {
  value = azurerm_user_assigned_identity.external_agent.principal_id
}

output "external_agent_apim_path" {
  value = "/agents/external/v1/responses"
}

output "fabric_agent_apim_path" {
  value = var.fabric_agent_backend_url == "" ? null : "/agents/fabric-iq/v1/responses"
}