##
# OPDG + Fabric firewall rules (documented baseline) + diagnostics
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
# The firewall diagnostic setting references the 40-monitoring workspace. Because
# each stage is an independent Terraform root, 40-monitoring must be applied before
# this setting. For a first-time deploy that follows 00->10->20->...->40 order,
# apply stage 20 once with enable_fw_diagnostics=false, deploy 40-monitoring, then
# re-apply stage 20 with it true (or simply apply 40-monitoring before 20).
locals {
  monitor_rg  = "azr-${var.env}-${var.org}-${var.subcode_monitor}-rg-monitor-network"
  monitor_law = "azr-${var.env}-${var.org}-${var.subcode_monitor}-law-central"
}

data "azurerm_log_analytics_workspace" "central" {
  count               = var.enable_fw_diagnostics ? 1 : 0
  name                = local.monitor_law
  resource_group_name = local.monitor_rg
}

# ---------- Firewall diagnostics -> LAW (resource-specific AZFW* tables) ----------
moved {
  from = azurerm_monitor_diagnostic_setting.firewall
  to   = azurerm_monitor_diagnostic_setting.firewall[0]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count                          = var.enable_fw_diagnostics ? 1 : 0
  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.hub.id
  log_analytics_workspace_id     = data.azurerm_log_analytics_workspace.central[0].id
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

resource "azurerm_firewall_policy_rule_collection_group" "foundry_ai_gateway" {
  # Tested deny-all baseline adapted from:
  # https://github.com/roie9876/Azure-AI-Foundry-Networking#firewall-rules-reference
  # Includes Agent Service image/identity endpoints, Sweden Central evaluation
  # registry/data-proxy endpoints, private-monitoring SDK configuration, and
  # APIM platform dependencies. SharePoint sync and fine-tuning sample FQDNs are
  # intentionally excluded until those optional features are enabled.
  # The reference's UDP/53 rule is not required here: the Foundry spoke uses
  # Azure-provided DNS and central Private DNS links, so 168.63.129.16 platform
  # DNS traffic is not sent through the UDR/firewall. Public App Insights
  # ingestion FQDNs are also omitted because ingestion resolves through AMPLS.
  name               = "foundry-ai-gateway"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 510

  application_rule_collection {
    name     = "foundry-runtime-allow"
    priority = 100
    action   = "Allow"

    rule {
      name = "agent-runtime-and-identity"
      source_addresses = [
        var.foundry_agent_subnet_cidr,
        var.foundry_tools_subnet_cidr,
      ]
      destination_fqdns = [
        "*.identity.azure.net",
        "*.data.mcr.microsoft.com",
        "*.login.microsoft.com",
        "*.login.microsoftonline.com",
        "login.microsoftonline.com",
        "mcr.microsoft.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  application_rule_collection {
    name     = "foundry-evaluation-allow"
    priority = 110
    action   = "Allow"

    rule {
      name = "evaluation-registry-and-data-proxy"
      source_addresses = [
        var.foundry_agent_subnet_cidr,
        var.foundry_tools_subnet_cidr,
      ]
      destination_fqdns = [
        "*.api.azureml.ms",
        "*.azureml.ms",
        "*.blob.core.windows.net",
        "*.dataproxy.swedencentral.api.azureml.ms",
        "*.experiments.azureml.net",
        "raw.githubusercontent.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  application_rule_collection {
    name     = "foundry-monitoring-allow"
    priority = 120
    action   = "Allow"

    rule {
      name = "application-insights-sdk"
      source_addresses = [
        var.foundry_agent_subnet_cidr,
        var.foundry_tools_subnet_cidr,
      ]
      destination_fqdns = [
        "settings.sdk.monitor.azure.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  application_rule_collection {
    name     = "apim-platform-allow"
    priority = 130
    action   = "Allow"

    rule {
      name             = "apim-dependencies"
      source_addresses = [var.apim_integration_subnet_cidr]
      destination_fqdns = [
        "*.blob.core.windows.net",
        "*.login.microsoftonline.com",
        "*.vault.azure.net",
        "login.microsoftonline.com",
      ]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  application_rule_collection {
    name     = "foundry-deny-log"
    priority = 300
    action   = "Deny"

    rule {
      name = "deny-all-web-log"
      source_addresses = [
        var.foundry_agent_subnet_cidr,
        var.foundry_tools_subnet_cidr,
        var.apim_integration_subnet_cidr,
      ]
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
