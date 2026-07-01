output "state_resource_group" {
  description = "Resource group hosting the Terraform state storage account."
  value       = azurerm_resource_group.state.name
}

output "state_storage_account" {
  description = "Storage account for Terraform remote state."
  value       = azurerm_storage_account.state.name
}

output "state_container" {
  description = "Blob container for Terraform state files."
  value       = azurerm_storage_container.state.name
}
