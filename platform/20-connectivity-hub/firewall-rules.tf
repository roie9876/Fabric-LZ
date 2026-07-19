##
# OPDG + Fabric firewall rules (documented baseline) + diagnostics + forced tunnel
#
# Purpose: route all on-premises traffic through the hub Azure Firewall and open
# ONLY the endpoints Microsoft documents for the on-premises data gateway (OPDG)
# and Microsoft Fabric. Deliberately NO service tags and NO FQDN tags — every rule
# is an explicit FQDN or IP so the exact same set can be replicated on a customer's
# on-premises firewall that has no Azure tag support.
#
# Sources (captured 2026-07-19):
#   * OPDG communication settings:
#     https://learn.microsoft.com/data-integration/gateway/service-gateway-communication
#   * Fabric allowlist URLs:
#     https://learn.microsoft.com/fabric/security/fabric-allow-list-urls
#
# Rule-processing order in Azure Firewall: DNAT -> Network -> Application.
# A network-rule match short-circuits application rules, so only IP/private-link
# and genuinely non-HTTP flows (AMQP, TDS 1433) live in the network collection;
# all HTTP/HTTPS lives in the application collection so the FQDN is logged.
#
# The trailing Deny (application) rule logs every *denied* web FQDN — that is how
# we discover endpoints the Microsoft docs missed. Update the allow rules above it
# as new required FQDNs surface in AZFWApplicationRule.
##

# ---------- Central Log Analytics (owned by 40-monitoring) ----------
locals {
  monitor_rg  = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  monitor_law = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"
}

data "azurerm_log_analytics_workspace" "central" {
  name                = local.monitor_law
  resource_group_name = local.monitor_rg
}

# ---------- Firewall diagnostics -> LAW (resource-specific AZFW* tables) ----------
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.hub.id
  log_analytics_workspace_id     = data.azurerm_log_analytics_workspace.central.id
  log_analytics_destination_type = "Dedicated" # populate AZFWNetworkRule / AZFWApplicationRule / AZFWDnsProxy

  enabled_log { category = "AZFWApplicationRule" }
  enabled_log { category = "AZFWNetworkRule" }
  enabled_log { category = "AZFWNatRule" }
  enabled_log { category = "AZFWThreatIntel" }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------- OPDG + Fabric rule collection group ----------
resource "azurerm_firewall_policy_rule_collection_group" "opdg_fabric" {
  name               = "opdg-fabric"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 500

  # ===== NETWORK rules: private-link IP only =====
  # Azure Firewall network rules do NOT accept wildcard FQDNs (validation error
  # FirewallPolicyRuleInvalidFqdnFormat). Only the IP-based private-link rule
  # lives here; every FQDN-based flow (Service Bus 443, Fabric TDS 1433) is an
  # application rule below (Https / Mssql), which DO support wildcard FQDNs.
  network_rule_collection {
    name     = "opdg-network-allow"
    priority = 100
    action   = "Allow"

    # Fabric private endpoints (data-plane over Private Link) — IP based.
    rule {
      name                  = "fabric-privatelink-443"
      protocols             = ["TCP"]
      source_addresses      = [var.onprem_source_cidr]
      destination_addresses = [var.fabric_pe_subnet_cidr]
      destination_ports     = ["443"]
    }
  }

  # ===== APPLICATION rules: all HTTP/HTTPS (FQDN logged in AZFWApplicationRule) =====
  application_rule_collection {
    name     = "opdg-app-allow"
    priority = 200
    action   = "Allow"

    # Microsoft Entra ID / OAuth2 sign-in.
    rule {
      name             = "gateway-auth"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "*.login.windows.net",
        "login.live.com",
        "aadcdn.msauth.net",
        "login.microsoftonline.com",
        "*.microsoftonline-p.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    # Core gateway function (cluster discovery, installer, relay token, telemetry, admin).
    rule {
      name             = "gateway-core"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "*.download.microsoft.com",
        "*.powerbi.com",
        "*.analysis.windows.net",
        "*.servicebus.windows.net",
        "*.dc.services.visualstudio.com",
        "ecs.office.com",
        "gatewayadminportal.azure.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    # Internet connectivity test (HTTP).
    rule {
      name              = "gateway-ncsi"
      source_addresses  = [var.onprem_source_cidr]
      destination_fqdns = ["*.msftncsi.com"]
      protocols {
        type = "Http"
        port = 80
      }
    }

    # Fabric workload execution (OneLake writes, DFS, pipeline front-end).
    rule {
      name             = "fabric-workload"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "*.core.windows.net",
        "*.dfs.fabric.microsoft.com",
        "*.frontend.clouddatahub.net",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    # Fabric platform + OneLake endpoints.
    rule {
      name             = "fabric-platform"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "*.fabric.microsoft.com",
        "*.onelake.dfs.fabric.microsoft.com",
        "*.onelake.blob.fabric.microsoft.com",
        "*.pbidedicated.windows.net",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }

    # Fabric SQL / Data Warehouse / Datamart / Azure-hosted sources over TDS (1433).
    # Azure Firewall application rules support the Mssql protocol with wildcard FQDNs.
    rule {
      name             = "fabric-sql-tds"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "*.datawarehouse.fabric.microsoft.com",
        "*.datawarehouse.pbidedicated.windows.net",
        "*.datawarehouse.pbidedicated.microsoft.com",
        "*.datamart.fabric.microsoft.com",
        "*.datamart.pbidedicated.microsoft.com",
        "*.pbidedicated.microsoft.com",
        "*.pbidedicated.windows.net",
        "*.database.fabric.microsoft.com",
        "*.cloudapp.azure.com",
      ]
      protocols {
        type = "Mssql"
        port = 1433
      }
    }

    # Certificate revocation / OCSP (HTTP 80 + HTTPS 443). Frequently missing from
    # docs; connectors that enforce CRL checks fail silently without these.
    rule {
      name             = "certificate-revocation"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "oneocsp.microsoft.com",
        "ocsp.digicert.com",
        "crl3.digicert.com",
        "crl4.digicert.com",
        "cacerts.digicert.com",
        "www.microsoft.com",
        "crl.microsoft.com",
        "ctldl.windowsupdate.com",
      ]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  # ===== APPLICATION: management-plane survival (Terraform runner / az) =====
  # When on-prem 0.0.0.0/0 is forced through the firewall (Stage B), the runner
  # (172.16.1.5, shares the OPDG subnet) sends its ARM/storage calls here too.
  # Without these the runner loses ARM and Terraform breaks. Kept as a SEPARATE
  # collection so it maps to the management path, not the OPDG workload, in prod.
  application_rule_collection {
    name     = "management-plane"
    priority = 150
    action   = "Allow"

    rule {
      name             = "runner-arm-storage"
      source_addresses = [var.onprem_source_cidr]
      destination_fqdns = [
        "management.azure.com",
        "management.core.windows.net",
        "*.blob.core.windows.net",
        "login.microsoftonline.com",
        "login.windows.net",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  # ===== APPLICATION deny-log: catch every web FQDN not allowed above =====
  # This is the discovery instrument. Anything the docs missed shows up here as a
  # Deny in AZFWApplicationRule with the exact FQDN. Promote it into an allow rule
  # once confirmed required, then this stays as the production default-deny.
  application_rule_collection {
    name     = "opdg-deny-log"
    priority = 300
    action   = "Deny"

    rule {
      name              = "deny-all-web-log"
      source_addresses  = [var.onprem_source_cidr]
      destination_fqdns = ["*"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

# ---------- Forced tunnel: on-prem -> Fabric spoke via the hub firewall ----------
# The GatewaySubnet has no route table by default, so on-prem->spoke traffic goes
# straight over the peering and bypasses the firewall. This UDR steers the Fabric
# spoke prefix to the firewall. BGP route propagation stays ENABLED so the gateway
# keeps learning/advertising all other routes.
resource "azurerm_route_table" "gateway" {
  count               = var.enable_gatewaysubnet_forced_tunnel ? 1 : 0
  name                = "azr-${var.env}-${var.org}-${var.subcode_connectivity}-rt-gatewaysubnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.net.name
  tags                = local.tags
}

resource "azurerm_route" "gw_to_fabric_via_fw" {
  count                  = var.enable_gatewaysubnet_forced_tunnel ? 1 : 0
  name                   = "fabric-spoke-to-firewall"
  resource_group_name    = azurerm_resource_group.net.name
  route_table_name       = azurerm_route_table.gateway[0].name
  address_prefix         = var.fabric_spoke_cidr
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "gateway" {
  count          = var.enable_gatewaysubnet_forced_tunnel ? 1 : 0
  subnet_id      = azurerm_subnet.gateway.id
  route_table_id = azurerm_route_table.gateway[0].id
}
