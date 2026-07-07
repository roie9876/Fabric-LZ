variable "subscription_id_workloads" {
  description = "Workloads subscription ID (hosts the Fabric spoke + capacity)."
  type        = string
}

variable "tenant_id" {
  description = "Entra tenant ID."
  type        = string
}

variable "env" {
  type    = string
  default = "sbx"
}

variable "org" {
  type    = string
  default = "lab"
}

variable "location" {
  type    = string
  default = "israelcentral"
}

# Subcodes used to locate Layer 1 resources by their deterministic names.
variable "subcode_connectivity" {
  description = "Subcode of the connectivity hub (to find hub VNet + firewall)."
  type        = string
  default     = "0001"
}

variable "subcode_monitor" {
  description = "Subcode of the monitor subscription (to find the central LAW)."
  type        = string
  default     = "0001"
}

variable "subcode_fabric" {
  description = "Subcode for Fabric spoke resource naming."
  type        = string
  default     = "0001"
}

variable "fabric_spoke_cidr" {
  description = "Fabric spoke VNet address space (non-overlapping with hub/on-prem)."
  type        = string
  default     = "10.2.0.0/24"
}

variable "fabric_pe_subnet_prefix" {
  description = "Private-endpoint subnet prefix in the Fabric spoke."
  type        = string
  default     = "10.2.0.0/27"
}

variable "fabric_capacity_sku" {
  description = "Microsoft Fabric capacity SKU (F2 is the smallest / cheapest)."
  type        = string
  default     = "F2"
}

variable "fabric_admin_upn" {
  description = "Entra UPN to set as the Fabric capacity administrator."
  type        = string
}
