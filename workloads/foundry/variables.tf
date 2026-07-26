variable "subscription_id_workloads" {
  description = "Subscription containing the Foundry workload."
  type        = string
}

variable "subscription_id_connectivity" {
  description = "Subscription containing the hub VNet, firewall, and central private DNS."
  type        = string
}

variable "subscription_id_monitor" {
  description = "Subscription containing the central Log Analytics workspace and AMPLS."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "monitoring_reader_principal_ids" {
  description = "Microsoft Entra object IDs in the workload tenant that can read Foundry traces and protected monitoring data."
  type        = set(string)
  default     = []
}

variable "env" {
  description = "Environment naming token."
  type        = string
  default     = "prd"
}

variable "org" {
  description = "Organization naming token."
  type        = string
  default     = "org"
}

variable "subcode_connectivity" {
  description = "Connectivity subscription naming token."
  type        = string
  default     = "0000"
}

variable "subcode_foundry" {
  description = "Foundry workload naming token."
  type        = string
  default     = "0000"
}

variable "subcode_monitor" {
  description = "Monitoring subscription naming token."
  type        = string
  default     = "0000"
}

variable "foundry_location" {
  description = "Azure region for Foundry and its injected VNet."
  type        = string
  default     = "swedencentral"
}

variable "ai_services_name_prefix" {
  description = "Prefix for AI Foundry account name"
  type        = string
  default     = "aifoundry"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "hybrid-agent-project"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.3.0.0/16"]
}

variable "model_name" {
  description = "The model to deploy"
  type        = string
  default     = "gpt-5-mini"
}

variable "model_version" {
  description = "The version of the model"
  type        = string
  default     = "2025-08-07"
}

variable "model_capacity" {
  description = "The capacity of the model deployment"
  type        = number
  default     = 40
}

variable "model_sku_name" {
  description = "Foundry model deployment SKU."
  type        = string
  default     = "GlobalStandard"
}

variable "search_sku_name" {
  description = "Azure AI Search dedicated SKU. Standard is the available production tier selected for this workload."
  type        = string
  default     = "standard"
}

variable "search_replica_count" {
  description = "Azure AI Search replicas. Two replicas provide query SLA."
  type        = number
  default     = 2
}

variable "search_partition_count" {
  description = "Azure AI Search partitions."
  type        = number
  default     = 1
}

########## BYO (Bring Your Own) resource variables
########## Leave empty to create new resources. Provide resource IDs to use existing ones.

variable "existing_resource_group_name" {
  description = "Name of an existing resource group. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_vnet_id" {
  description = "Resource ID of an existing VNet. Leave empty to create a new one. When provided, existing subnet IDs must also be provided."
  type        = string
  default     = ""
}

variable "existing_agent_subnet_id" {
  description = "Resource ID of an existing agent subnet (must be delegated to Microsoft.App/environments). Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_pe_subnet_id" {
  description = "Resource ID of an existing private endpoint subnet. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_mcp_subnet_id" {
  description = "Resource ID of an existing MCP subnet (must be delegated to Microsoft.App/environments). Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_storage_account_id" {
  description = "Resource ID of an existing Storage Account. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_cosmosdb_account_id" {
  description = "Resource ID of an existing Cosmos DB account. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_ai_search_id" {
  description = "Resource ID of an existing AI Search service. Leave empty to create a new one."
  type        = string
  default     = ""
}

variable "existing_dns_zones_resource_group" {
  description = "Resource group containing existing private DNS zones. Leave empty to create new zones. When provided, all 6 zones are expected to exist in this RG."
  type        = string
  default     = ""
}

variable "existing_dns_zones_subscription_id" {
  description = "Subscription ID where existing private DNS zones are located. Leave empty to use the current subscription. Only used when existing_dns_zones_resource_group is set."
  type        = string
  default     = ""
}

variable "existing_blob_private_dns_zone_resource_group_name" {
  description = "Resource group containing the authoritative privatelink.blob.core.windows.net zone. Leave null to create it centrally."
  type        = string
  default     = null
}

variable "existing_fabric_workspace_id" {
  description = "Resource ID of an existing Fabric workspace for Data Agent private endpoint. Leave empty to skip Fabric integration."
  type        = string
  default     = ""
}

variable "fabric_data_agent_workspace_id" {
  description = "Fabric workspace GUID containing the published Data Agent. Leave empty to skip the prompt-agent connection."
  type        = string
  default     = ""
}

variable "fabric_data_agent_artifact_id" {
  description = "Published Fabric Data Agent artifact GUID. Leave empty to skip the prompt-agent connection."
  type        = string
  default     = ""
}

variable "fabric_prompt_model_name" {
  description = "Model deployment used by the Fabric Data Agent prompt agent."
  type        = string
  default     = "gpt-4.1-mini"
}

variable "fabric_prompt_model_version" {
  description = "Model version used by the Fabric Data Agent prompt agent."
  type        = string
  default     = "2025-04-14"
}

variable "fabric_prompt_model_capacity" {
  description = "GlobalStandard capacity for the Fabric-compatible prompt model."
  type        = number
  default     = 10
}

########## Optional: Azure Container Registry
########## Enable to create a Premium ACR with Private Endpoint for hosted agent containers.

variable "enable_container_registry" {
  description = "Enable Azure Container Registry with Private Endpoint for hosted agent containers"
  type        = bool
  default     = false
}

variable "developer_ip_cidr" {
  description = "Optional developer IP CIDR to allowlist for ACR push access (e.g., 203.0.113.0/26). Only used when enable_container_registry is true. When empty, public access remains disabled."
  type        = string
  default     = ""
}
