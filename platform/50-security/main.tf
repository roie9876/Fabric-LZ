##
# Stage 50 — Security
#
# Tenant/subscription security posture:
#   * Microsoft Defender for Cloud plans (CSPM + workload protection)
#   * CNAPP onboarding hooks (vendor-agnostic; brand/config kept private)
#
# Starter skeleton — enable Defender plans per subscription and wire the CNAPP
# connector using values from the private overlay.
##

variable "subscription_id_security" {
  description = "Security/DevSecOps subscription ID (real value from _private)."
  type        = string
}

variable "tenant_id" {
  type = string
}

# Example: enable Defender for Cloud plans (extend the list as required).
# resource "azurerm_security_center_subscription_pricing" "vm" {
#   tier          = "Standard"
#   resource_type = "VirtualMachines"
# }
