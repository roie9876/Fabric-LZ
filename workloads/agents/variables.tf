variable "subscription_id_workloads" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "use_msi" {
  description = "Use managed identity on the private Terraform runner."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  type    = string
  default = "azr-sbx-lab-0001-rg-foundry"
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "foundry_vnet_name" {
  type    = string
  default = "azr-sbx-lab-0001-vnet-foundry"
}

variable "hub_resource_group_name" {
  type    = string
  default = "azr-sbx-lab-0001-rg-net-hub"
}

variable "hub_vnet_name" {
  type    = string
  default = "azr-sbx-lab-0001-vnet-hub-core"
}

variable "container_apps_subnet_name" {
  type    = string
  default = "mcp-subnet"
}

variable "foundry_account_name" {
  type    = string
  default = "azrsbxlab0001aif2690"
}

variable "foundry_project_endpoint" {
  type    = string
  default = "https://azrsbxlab0001aif2690.services.ai.azure.com/api/projects/azr-sbx-lab-0001-project-agent"
}

variable "model_deployment_name" {
  type    = string
  default = "gpt-5-mini"
}

variable "container_registry_name" {
  type    = string
  default = "acr2690"
}

variable "application_insights_name" {
  type    = string
  default = "azr-sbx-lab-0001-appi-foundry"
}

variable "log_analytics_workspace_name" {
  type    = string
  default = "azr-sbx-lab-0001-law-central"
}

variable "log_analytics_resource_group_name" {
  type    = string
  default = "azr-sbx-lab-0001-rg-monitor-network"
}

variable "external_agent_image" {
  description = "Immutable private ACR image reference, including tag or digest."
  type        = string
}

variable "api_management_name" {
  type    = string
  default = "azr-sbx-lab-0001-apim-8833"
}

variable "api_audience" {
  description = "Entra application ID URI accepted by APIM for agent callers."
  type        = string
}

variable "fabric_agent_backend_url" {
  description = "Hosted agent Responses protocol endpoint. Leave empty until the first agent version is deployed."
  type        = string
  default     = ""
}

variable "tags" {
  type = map(string)
  default = {
    layer   = "workload"
    stage   = "agents"
    managed = "terraform"
  }
}