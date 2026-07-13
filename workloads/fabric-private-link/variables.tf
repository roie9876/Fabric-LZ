variable "subscription_id_workloads" {
  description = "Workloads subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
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

variable "subcode_connectivity" {
  description = "Subcode used by the Layer 1 connectivity hub."
  type        = string
  default     = "0001"
}

variable "subcode_fabric" {
  description = "Subcode used by the Fabric workload."
  type        = string
  default     = "0001"
}

variable "fabric_private_workspace_id" {
  description = "Object ID of the Fabric workspace that will use restricted inbound access."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.fabric_private_workspace_id))
    error_message = "fabric_private_workspace_id must be a GUID including dashes."
  }
}