# OPDG + Fabric firewall rules (hub Azure Firewall)

This document is the **authoritative, tag-free** list of firewall rules required for the
on-premises data gateway (OPDG) and Microsoft Fabric in this landing zone. It is written so
the **same rules can be re-created on a customer on-premises firewall** that does not support
Azure service tags or FQDN tags — every rule is an explicit **FQDN** or **IP/port**.

- Implemented as code in [platform/20-connectivity-hub/firewall-rules.tf](../platform/20-connectivity-hub/firewall-rules.tf)
  (rule collection group `opdg-fabric` on policy `azr-sbx-lab-0001-fwpol-hub`).
- Sources (captured 2026-07-19):
  - OPDG communication settings — https://learn.microsoft.com/data-integration/gateway/service-gateway-communication
  - Fabric allowlist URLs — https://learn.microsoft.com/fabric/security/fabric-allow-list-urls

> **No Azure tags by design.** Microsoft's docs offer `PowerBI`, `ServiceBus`,
> `AzureActiveDirectory`, `AzureCloud`, `DataFactory` service tags. We do **not** use them —
> the customer firewall can't consume tags, and we want the explicit FQDN/IP list that a
> classic firewall needs.

## How this set is used to discover missing rules

Azure Firewall evaluates rules **DNAT → Network → Application** (first match wins; a network
match skips application rules). Therefore:

- **Network collection** = private-link IPs + genuinely non-HTTP flows only (AMQP relay, TDS 1433).
- **Application collection** = all HTTP/HTTPS, so the **FQDN** is captured in `AZFWApplicationRule`.
- A trailing **`Deny` application rule (`* :80,443`)** logs every web FQDN that is *not* allowed
  above. Run the OPDG workload, then read the denies — that is exactly the list of endpoints the
  Microsoft docs missed. Promote each confirmed one into an allow rule and re-apply.

Discovery query:

```kql
// endpoints attempted but not yet in the allow list
AZFWApplicationRule
| where TimeGenerated > ago(2h)
| where Action == "Deny"
| summarize count() by Fqdn, DestinationPort
| order by count_ desc
```
```kql
// non-HTTP flows that reached the firewall (relay / TDS / private-link)
AZFWNetworkRule
| where TimeGenerated > ago(2h)
| summarize count() by SourceIp, DestinationIp, DestinationPort, Action, Protocol
| order by count_ desc
```

## Network rules — `opdg-network-allow` (priority 100, Allow)

Source for all rules: `172.16.0.0/16` (on-premises).

| Rule | Destination | Ports | Why |
|---|---|---|---|
| `fabric-privatelink-443` | `10.2.0.0/27` (Fabric PE subnet, IPs `10.2.0.4-.8`) | TCP 443 | Fabric data-plane over Private Link |
| `servicebus-relay` | `*.servicebus.windows.net` | TCP 5671, 5672, 9350-9354 | Azure Relay / Service Bus (gateway cloud connectivity, AMQP) |
| `fabric-tds-1433` | `*.datawarehouse.fabric.microsoft.com`, `*.datawarehouse.pbidedicated.windows.net`, `*.datawarehouse.pbidedicated.microsoft.com`, `*.datamart.fabric.microsoft.com`, `*.datamart.pbidedicated.microsoft.com`, `*.pbidedicated.microsoft.com`, `*.pbidedicated.windows.net`, `*.database.fabric.microsoft.com` | TCP 1433 | Fabric DW / Datamart / staging lakehouse (TDS) |
| `fabric-sqldb-redirect` | `*.database.fabric.microsoft.com` | TCP 11000-11999 | SQL DB in Fabric, redirect connection policy |
| `cloudapp-tds-1433` | `*.cloudapp.azure.com` | TCP 1433 | Data sources on Azure VMs/Cloud Services (doc says 1443 — treated as 1433 typo) |

> FQDN-based **network** rules require **DNS proxy** enabled on the policy *and* on-prem clients
> using the firewall as their DNS server (see companion changes below), otherwise the firewall
> and client may resolve to different IPs and the rule won't match.

## Application rules — `opdg-app-allow` (priority 200, Allow)

Source for all rules: `172.16.0.0/16` (on-premises).

| Rule | FQDNs | Ports | Why |
|---|---|---|---|
| `gateway-auth` | `*.login.windows.net`, `login.live.com`, `aadcdn.msauth.net`, `login.microsoftonline.com`, `*.microsoftonline-p.com` | 443 | Entra ID / OAuth2 sign-in |
| `gateway-core` | `*.download.microsoft.com`, `*.powerbi.com`, `*.analysis.windows.net`, `*.servicebus.windows.net`, `*.dc.services.visualstudio.com`, `ecs.office.com`, `gatewayadminportal.azure.com` | 443 | Cluster discovery, installer, relay token, telemetry, admin |
| `gateway-ncsi` | `*.msftncsi.com` | 80 | Internet connectivity test |
| `fabric-workload` | `*.core.windows.net`, `*.dfs.fabric.microsoft.com`, `*.frontend.clouddatahub.net` | 443 | OneLake writes, DFS, pipeline front-end |
| `fabric-platform` | `*.fabric.microsoft.com`, `*.onelake.dfs.fabric.microsoft.com`, `*.onelake.blob.fabric.microsoft.com`, `*.pbidedicated.windows.net` | 443 | Fabric portal + OneLake |
| `certificate-revocation` | `oneocsp.microsoft.com`, `ocsp.digicert.com`, `crl3.digicert.com`, `crl4.digicert.com`, `cacerts.digicert.com`, `www.microsoft.com`, `crl.microsoft.com`, `ctldl.windowsupdate.com` | 80, 443 | CRL / OCSP checks (often missing from docs) |

## Default deny (discovery instrument) — `opdg-deny-log` (priority 300, Deny)

| Rule | FQDNs | Ports | Why |
|---|---|---|---|
| `deny-all-web-log` | `*` | 80, 443 | Log every web FQDN not explicitly allowed. Becomes the production default-deny. |

## Companion changes (also in Terraform)

These make the traffic actually traverse the firewall and make FQDN rules resolvable:

1. **DNS proxy** on the firewall policy → servers = hub resolver inbound (`10.0.0.100`).
   [platform/20-connectivity-hub/main.tf](../platform/20-connectivity-hub/main.tf)
2. **Firewall diagnostics** → central LAW, `Dedicated` destination type, categories
   `AZFWApplicationRule`, `AZFWNetworkRule`, `AZFWNatRule`, `AZFWDnsProxy`, `AZFWThreatIntel`.
3. **Forced tunnel (forward path):** route table on `GatewaySubnet` → `10.2.0.0/24` to the
   firewall. BGP propagation stays enabled.
   [platform/20-connectivity-hub/firewall-rules.tf](../platform/20-connectivity-hub/firewall-rules.tf)
4. **Forced tunnel (return path):** pe-subnet route `172.16.0.0/16` → firewall, so PE→on-prem
   traffic hairpins back symmetrically. [workloads/fabric/main.tf](../workloads/fabric/main.tf)
5. **On-prem VNet DNS → `10.0.0.4`** (the firewall) — manual/`onprem-lab` step, so client and
   firewall resolve FQDNs identically (required for FQDN network rules).
6. *(Optional, to also inspect www)* on-prem default route `0.0.0.0/0` into the tunnel → firewall.

## Apply notes

- Remove the temporary manual `allow-all` network rule (in `DefaultNetworkRuleCollectionGroup`)
  so these documented rules take effect and gaps surface as denies:
  `az network firewall policy rule-collection-group delete --policy-name azr-sbx-lab-0001-fwpol-hub -g azr-sbx-lab-0001-rg-fw-hub -n DefaultNetworkRuleCollectionGroup`
- Apply stage 20 **targeted** to avoid the known `azurerm_public_ip.fw` replacement drift:
  target `azurerm_firewall_policy.hub`, `azurerm_firewall_policy_rule_collection_group.opdg_fabric`,
  `azurerm_monitor_diagnostic_setting.firewall`, and the `azurerm_route*`/association for GatewaySubnet.

## Discovered gaps (fill in after each run)

| Date | FQDN / IP:port | Action taken |
|---|---|---|
| _tbd_ | | |
