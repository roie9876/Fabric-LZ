variable "subscription_id_workloads" {
  description = "Subscription containing the simulated on-prem environment."
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
  type    = string
  default = "0001"
}

variable "onprem_resource_group_name" {
  description = "Existing resource group that hosts the S2S on-prem simulation."
  type        = string
  default     = "azr-sbx-lab-0001-rg-onprem-sim"
}

variable "onprem_vnet_name" {
  description = "Existing simulated on-prem VNet."
  type        = string
  default     = "onprem-vnet"
}

variable "onprem_subnet_name" {
  description = "Existing subnet with NAT and S2S reachability."
  type        = string
  default     = "workload"
}

variable "sql_private_ip" {
  type    = string
  default = "172.16.1.10"
}

variable "opdg_private_ip" {
  type    = string
  default = "172.16.1.11"
}

variable "sql_vm_size" {
  description = "Reduced-cost lab size. Customer production sizing requires workload testing."
  type        = string
  default     = "Standard_B4ms"
}

variable "opdg_vm_size" {
  description = "Minimum lab size. Microsoft recommends 8 cores and 8 GB or more for production OPDG."
  type        = string
  default     = "Standard_B2s"
}

variable "windows_admin_username" {
  type    = string
  default = "lzadmin"
}