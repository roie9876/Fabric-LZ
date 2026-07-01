variable "subscription_id_management" {
  description = "Management/platform subscription ID (real value from _private)."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID (real value from _private)."
  type        = string
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "westeurope"
}

variable "org" {
  description = "Organization naming prefix. 'org' is the public placeholder."
  type        = string
  default     = "org"
}

variable "env" {
  description = "Environment token."
  type        = string
  default     = "prd"
}

variable "subcode_management" {
  description = "Subscription short-code for the management subscription."
  type        = string
  default     = "0000"
}
