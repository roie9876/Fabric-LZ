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
  - Azure Firewall FQDN filtering in network rules —
    https://learn.microsoft.com/azure/firewall/fqdn-filtering-network-rules

> **No Azure tags by design.** Microsoft's docs offer `PowerBI`, `ServiceBus`,
> `AzureActiveDirectory`, `AzureCloud`, `DataFactory` service tags. We do **not** use them —
> the customer firewall can't consume tags, and we want the explicit FQDN/IP list that a
> classic firewall needs.

## How this set is used to discover missing rules

Azure Firewall evaluates rules **DNAT → Network → Application** (first match wins; a network
match skips application rules). Therefore:

- **Network collection** = the IP-based private-link rule. Azure Firewall network-rule
  FQDN filtering does not support wildcards.
- **Application collection** = HTTP, HTTPS, and MSSQL rules, so wildcard FQDNs are
  supported and captured in `AZFWApplicationRule`.
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
// IP-based private-link flows that reached the firewall
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

> Do not move the wildcard FQDN entries below into network rules. Azure Firewall
> supports FQDN filtering in network rules only when DNS proxy is enabled, but
> wildcard FQDNs are not supported there by design. Use application rules for
> HTTP, HTTPS, and MSSQL FQDN filtering.

## Application rules — `opdg-app-allow` (priority 200, Allow)

Source for all rules: `172.16.0.0/16` (on-premises).

| Rule | FQDNs | Ports | Why |
|---|---|---|---|
| `gateway-auth` | `*.login.windows.net`, `login.live.com`, `aadcdn.msauth.net`, `login.microsoftonline.com`, `*.microsoftonline-p.com` | 443 | Entra ID / OAuth2 sign-in |
| `gateway-core` | `*.download.microsoft.com`, `*.powerbi.com`, `*.analysis.windows.net`, `*.servicebus.windows.net`, `*.dc.services.visualstudio.com`, `ecs.office.com`, `gatewayadminportal.azure.com` | 443 | Cluster discovery, installer, relay token, telemetry, admin |
| `gateway-ncsi` | `*.msftncsi.com` | 80 | Internet connectivity test |
| `fabric-workload` | `*.core.windows.net`, `*.dfs.fabric.microsoft.com`, `*.frontend.clouddatahub.net` | 443 | OneLake writes, DFS, pipeline front-end |
| `fabric-platform` | `*.fabric.microsoft.com`, `*.onelake.dfs.fabric.microsoft.com`, `*.onelake.blob.fabric.microsoft.com`, `*.pbidedicated.windows.net` | 443 | Fabric portal + OneLake |
| `fabric-sql-tds` | `*.datawarehouse.fabric.microsoft.com`, `*.datawarehouse.pbidedicated.windows.net`, `*.datawarehouse.pbidedicated.microsoft.com`, `*.datamart.fabric.microsoft.com`, `*.datamart.pbidedicated.microsoft.com`, `*.pbidedicated.microsoft.com`, `*.pbidedicated.windows.net`, `*.database.fabric.microsoft.com`, `*.cloudapp.azure.com` | MSSQL 1433 | Fabric DW, Datamart, staging lakehouse, and Azure-hosted SQL sources through the application-level MSSQL proxy |
| `certificate-revocation` | `oneocsp.microsoft.com`, `ocsp.digicert.com`, `crl3.digicert.com`, `crl4.digicert.com`, `cacerts.digicert.com`, `www.microsoft.com`, `crl.microsoft.com`, `ctldl.windowsupdate.com` | 80, 443 | CRL / OCSP checks (often missing from docs) |

## Default deny (discovery instrument) — `opdg-deny-log` (priority 300, Deny)

| Rule | FQDNs | Ports | Why |
|---|---|---|---|
| `deny-all-web-log` | `*` | 80, 443 | Log every web FQDN not explicitly allowed. Becomes the production default-deny. |

## Companion changes (also in Terraform)

On-prem reaches the hub over **VNet peering** and the hub firewall is the transit /
default gateway. The rules only matter once traffic is routed to the firewall:

1. **DNS proxy** on the firewall policy → servers = hub resolver inbound (`10.0.0.100`).
   [platform/20-connectivity-hub/main.tf](../platform/20-connectivity-hub/main.tf)
2. **Firewall diagnostics** → central LAW, `Dedicated` destination type, categories
   `AZFWApplicationRule`, `AZFWNetworkRule`, `AZFWNatRule`, `AZFWThreatIntel`
   (`AZFWDnsProxy` is not a supported category on this SKU/region).
3. **On-prem → firewall (forward path):** the on-prem workload subnet UDR sends the
   Fabric spoke prefix and `0.0.0.0/0` to the firewall (`10.0.0.4`). Because on-prem is
   **peered** to the hub, the firewall is a valid VirtualAppliance next hop. *(Applied on
   the on-prem sim via CLI; the on-prem network is not in a Terraform root.)*
4. **Return path:** pe-subnet route `172.16.0.0/16` → firewall, so PE→on-prem traffic
   transits the firewall symmetrically (VNet peering is non-transitive).
   [workloads/fabric/main.tf](../workloads/fabric/main.tf)
5. **Management-plane survival:** when the Terraform runner shares the on-prem subnet,
   the `management-plane` rule allows `management.azure.com`, `*.blob.core.windows.net`,
   etc. so the runner keeps ARM/state access through the firewall.

## Apply notes

- Remove any temporary broad `allow-all` rule so the documented rules take effect and
  gaps surface as denies.
- Apply stage 20 **targeted** to keep the change surgical (PIP replacement drift is
  suppressed via `lifecycle { ignore_changes = [ip_tags, zones] }`): target
  `azurerm_firewall_policy.hub`, `azurerm_firewall_policy_rule_collection_group.opdg_fabric`,
  and `azurerm_monitor_diagnostic_setting.firewall`.

## Discovered gaps (fill in after each run)

| Date | FQDN / IP:port | Action taken |
|---|---|---|
| _tbd_ | | |
