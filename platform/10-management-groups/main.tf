##
# Stage 10 — Management Groups
#
# Builds the MG hierarchy and (optionally) places subscriptions.
#   Tenant Root
#   ├── mgmt        platform / connectivity / management
#   ├── workloads   Fabric, Foundry, business workloads
#   ├── monitor     centralized observability
#   └── sandbox     experimentation
#
# Starter skeleton — attach subscriptions and Azure Policy assignments as the
# governance model is finalized.
##

resource "azurerm_management_group" "mgmt" {
  display_name = "mgmt"
}

resource "azurerm_management_group" "workloads" {
  display_name = "workloads"
}

resource "azurerm_management_group" "monitor" {
  display_name = "monitor"
}

resource "azurerm_management_group" "sandbox" {
  display_name = "sandbox"
}
