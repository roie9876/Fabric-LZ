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

# ---------- Monitoring (for firewall diagnostics) ----------
variable "subcode_monitor" {
  description = "Subcode of the monitoring stage (40-monitoring) that owns the central Log Analytics workspace."
  type        = string
  default     = "0000"
}

# ---------- OPDG / Fabric firewall-inspection discovery ----------
# These drive the documented OPDG + Fabric firewall rule set and the
# forced-tunnel routing that steers on-prem traffic through the hub firewall
# so its flow logs enumerate every required flow.
variable "onprem_source_cidr" {
  description = "On-premises address space that the gateway/SQL VMs live in (traffic source for FW rules)."
  type        = string
  default     = "172.16.0.0/16"
}

variable "fabric_spoke_cidr" {
  description = "Fabric spoke VNet CIDR — forced through the firewall from the GatewaySubnet."
  type        = string
  default     = "10.2.0.0/24"
}

variable "fabric_pe_subnet_cidr" {
  description = "Fabric private-endpoint subnet CIDR — destination of the private-link network rule (TCP 443)."
  type        = string
  default     = "10.2.0.0/27"
}

variable "enable_fw_dns_proxy" {
  description = "Enable DNS proxy on the firewall policy (required for FQDN-based network rules and FQDN flow-log visibility)."
  type        = bool
  default     = true
}

variable "dns_proxy_servers" {
  description = "Upstream DNS servers the firewall proxy forwards to (the hub Private DNS Resolver inbound endpoint)."
  type        = list(string)
  default     = ["10.0.0.100"]
}

variable "enable_gatewaysubnet_forced_tunnel" {
  description = "Attach a route table to GatewaySubnet that forces on-prem -> Fabric spoke traffic through the hub firewall."
  type        = bool
  default     = true
}
