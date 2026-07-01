##
# modules/naming — deterministic resource names following the LZ scheme:
#   azr-<env>-<org>-<subcode>-<type>-<role>
#
# The SCHEME is public; real `org` and `subcode` values come from the caller
# (ultimately from _private/*.private.tfvars).
##

variable "env" {
  description = "Environment token (e.g. prd, npr, sbx)."
  type        = string
  validation {
    condition     = can(regex("^(prd|npr|dev|tst|sbx)$", var.env))
    error_message = "env must be one of: prd, npr, dev, tst, sbx."
  }
}

variable "org" {
  description = "Organization prefix. Real value supplied privately; 'org' is the public placeholder."
  type        = string
  default     = "org"
}

variable "subcode" {
  description = "Subscription short-code embedded in names. '0000' is the public placeholder."
  type        = string
  default     = "0000"
}

variable "type" {
  description = "Resource type token (e.g. rg, vnet, fw, pe, dns)."
  type        = string
}

variable "role" {
  description = "Purpose token (e.g. hub, apim, monitor, egress)."
  type        = string
}

locals {
  name = lower(format("azr-%s-%s-%s-%s-%s", var.env, var.org, var.subcode, var.type, var.role))

  # Design mandate: every name must match the approved regex before apply.
  naming_regex = "^azr-(prd|npr|dev|tst|sbx)-[a-z0-9]+-[a-z0-9]+-[a-z]+-[a-z0-9-]+$"
}

# Fail fast if a constructed name violates the convention.
resource "terraform_data" "naming_guard" {
  lifecycle {
    precondition {
      condition     = can(regex(local.naming_regex, local.name))
      error_message = "Constructed name '${local.name}' violates the naming convention regex."
    }
  }
}

output "name" {
  description = "The fully-formed resource name."
  value       = local.name
}
