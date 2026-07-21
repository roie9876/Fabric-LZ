variable "subscription_id_workloads" {
  type = string
}

variable "subscription_id_connectivity" {
  type = string
}

variable "subscription_id_monitor" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "env" {
  type    = string
  default = "prd"
}

variable "org" {
  type    = string
  default = "org"
}

variable "subcode_connectivity" {
  type    = string
  default = "0000"
}

variable "subcode_foundry" {
  type    = string
  default = "0000"
}

variable "subcode_monitor" {
  type    = string
  default = "0000"
}

variable "foundry_location" {
  type    = string
  default = "swedencentral"
}

variable "apim_integration_subnet_prefix" {
  description = "Dedicated Standard v2 outbound integration subnet (/27 minimum)."
  type        = string
  default     = "10.3.3.0/27"
}

variable "apim_publisher_name" {
  type    = string
  default = "Platform Engineering"
}

variable "apim_publisher_email" {
  type = string
}

variable "apim_public_network_access_enabled" {
  description = "Temporarily set true only for initial APIM activation; converge to false immediately after the private endpoint is created."
  type        = bool
  default     = false
}