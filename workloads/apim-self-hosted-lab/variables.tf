variable "subscription_id" {
  description = "Azure subscription that owns the isolated APIM lab."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant for the APIM lab."
  type        = string
}

variable "use_msi" {
  description = "Use the private runner system-assigned managed identity."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Existing simulated on-premises resource group."
  type        = string
  default     = "azr-sbx-lab-0001-rg-onprem-sim"
}

variable "location" {
  description = "Azure region for the APIM Developer control plane."
  type        = string
  default     = "israelcentral"
}

variable "api_management_name" {
  description = "Globally unique APIM Developer classic instance name."
  type        = string
}

variable "publisher_name" {
  description = "Publisher name displayed by API Management."
  type        = string
  default     = "Platform Engineering"
}

variable "publisher_email" {
  description = "Publisher email required by API Management."
  type        = string
}

variable "gateway_name" {
  description = "Self-hosted gateway resource associated with the runner."
  type        = string
  default     = "onprem-runner"
}

variable "tags" {
  description = "Resource tags for ownership and cleanup."
  type        = map(string)
  default = {
    environment = "lab"
    managed_by  = "terraform"
    purpose     = "apim-self-hosted-gateway-evaluation"
  }
}