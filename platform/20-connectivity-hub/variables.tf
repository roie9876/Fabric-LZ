variable "subscription_id_connectivity" {
  description = "Connectivity/networking subscription ID (real value from _private)."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID (real value from _private)."
  type        = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "org" {
  type    = string
  default = "org"
}

variable "env" {
  type    = string
  default = "prd"
}

variable "subcode_connectivity" {
  type    = string
  default = "0000"
}

variable "hub_vnet_cidr" {
  description = "Hub VNet address space (real value from _private; use x.x.x.x/23 in public examples)."
  type        = string
  default     = "10.0.0.0/23"
}

variable "subnet_prefixes" {
  description = "Hub subnet prefixes. Real values from _private."
  type = object({
    firewall     = string
    gateway      = string
    dns_inbound  = string
    dns_outbound = string
    egress_swg   = string
  })
  default = {
    firewall     = "10.0.0.0/26"
    gateway      = "10.0.0.64/27"
    dns_inbound  = "10.0.0.96/28"
    dns_outbound = "10.0.0.112/28"
    egress_swg   = "10.0.0.128/27"
  }
}

variable "enable_ddos" {
  description = "Create a DDoS protection plan for hub public IPs."
  type        = bool
  default     = true
}
