##
# Stage 30 — Secure Egress
#
# Forces all internet-bound traffic through a 3rd-party Secure Web Gateway (SWG)
# NVA reachable from the hub. This module is VENDOR-AGNOSTIC: it consumes the
# NVA private IP and (optionally) FQDN allow-lists as inputs. The actual brand
# and appliance config live in the private overlay.
#
# Starter skeleton. Typical contents:
#   * Route table sending 0.0.0.0/0 to the SWG NVA private IP
#   * Association to spoke subnets (via modules/udr)
#   * Firewall policy rules permitting Spoke -> SWG only
##

variable "egress_nva_private_ip" {
  description = "Private IP of the SWG NVA (real value from _private)."
  type        = string
  default     = "10.0.0.4"
}

# Example route table; associate with spokes via modules/udr.
# resource "azurerm_route_table" "egress" { ... next_hop = var.egress_nva_private_ip }
