# 00 — Landing Zone overview

A sanitized summary of the target architecture. All customer-, partner-, and
environment-specific values are replaced with tokens (`<ORG>`, `0000`,
`x.x.x.x`).

## Goals

- A regulated-enterprise-grade **Hub & Spoke** landing zone.
- Two first workloads: **Microsoft Fabric** and **Microsoft Foundry + AI Search
  + APIM**.
- Everything deployed as code (Terraform), no manual production changes.

## Mandatory design principles

1. All deployment via **Terraform only**; no manual creation in production.
2. Code stored in Git, executed through CI/CD with approvals and security gates.
3. **Hub & Spoke** network topology using classic VNet peering + UDR (no AVNM).
4. All traffic **Spoke↔Spoke** and **Spoke↔On-Prem** traverses **Azure Firewall**.
5. Internet egress **only** through a 3rd-party **Secure Web Gateway (SWG)**.
6. Public IP protection in the hub via **Azure DDoS Protection**.
7. Most workloads are published externally through **Azure API Management**.

## Management group hierarchy

```
Tenant Root
├── mgmt        platform / connectivity / management
├── workloads   Fabric, Foundry, business workloads
├── monitor     centralized observability
└── sandbox     experimentation, isolated
```

## Subscription responsibility mapping (tokenized)

| Management Group | Subscription (token)                     | Purpose |
|---|---|---|
| mgmt / connectivity | `azr-<SUBCODE>-infra-networking-*`   | Hub networking, Firewall, DNS, egress |
| mgmt / connectivity | `azr-<SUBCODE>-infra-apim-*`         | API Management publishing platform |
| mgmt / devsecops    | `azr-<SUBCODE>-security-cnapp-*`     | DevSecOps + CNAPP tooling |
| monitor             | `azr-<SUBCODE>-infra-monitoring-*`   | Log Analytics, alerts, action groups |

## Connectivity hub components

- Hub VNet with **Azure Firewall** (Standard SKU, + Firewall Policy)
- **ExpressRoute Gateway** to on-prem (zone-redundant SKU)
- **Azure DDoS Protection** plan
- **Private DNS Resolver** (inbound + outbound)
- **Secure egress** subnet routing `0.0.0.0/0` to the SWG NVA
- Central diagnostic logs shipped to the monitor subscription

## Hybrid connectivity (ExpressRoute)

- **Dual ExpressRoute circuits** for high availability (active/active).
- Each circuit sized for high bandwidth (e.g. 10 Gbps).
- **MACsec** (layer-2) encryption on each circuit.
- **Bidirectional BGP** with documented, tested failover paths.
- Zone-redundant ExpressRoute Gateway.

## Security & governance

- **Microsoft Defender for Cloud** enabled at **tenant scope** — CSPM +
  Workload Protection across all relevant subscriptions.
- A complementary **CNAPP** layer for continuous configuration, exposure and
  attack-path scanning (vendor kept generic / private).
- **TLS 1.2 / 1.3** enforced for traffic traversing the firewall.
- **Naming enforcement**: every Resource Group is created only through a
  dedicated Terraform module with a naming-regex check in CI before `apply`.

## Environment tiers

Spoke VNets are provisioned per workload environment: **Prod / pre-Prod / Test /
Dev**, each traffic-isolated and governed by the same central policies.

## Traffic flows (enforced)

| Flow | Path | Control |
|---|---|---|
| Spoke → Spoke | Spoke A → Azure Firewall → Spoke B | forced UDR + FW policy |
| Spoke → On-Prem | Spoke → Firewall → ER Gateway → On-Prem | FW policy + BGP |
| On-Prem → Spoke | On-Prem → ER Gateway → Firewall → Spoke | FW policy |
| Spoke → Internet | Spoke → Firewall → SWG → Internet | NSG/UDR/Policy block direct egress |

> No direct VNet peering between spokes — all inter-spoke traffic is via the hub
> firewall.

## Address plan (tokenized)

| Environment | VNet | CIDR | Subscription |
|---|---|---|---|
| Connectivity Hub | `azr-<ORG>-vnet-hub-core` | `x.x.x.x/23` | networking |
| APIM Shared      | `azr-<ORG>-vnet-apim-shared` | `x.x.x.x/24` | apim |
| Monitor (AMPLS)  | `azr-<ORG>-vnet-monitor` | `x.x.x.x/24` | monitoring |
| Fabric spoke     | `azr-<ORG>-vnet-fabric` | `x.x.x.x/16` | workloads |
| Foundry spoke    | `azr-<ORG>-vnet-foundry` | `x.x.x.x/16` | workloads |

## Hub subnets (tokenized)

| Subnet | CIDR | Role |
|---|---|---|
| `AzureFirewallSubnet` | `x.x.x.x/26` | Azure Firewall data plane |
| `GatewaySubnet` | `x.x.x.x/27` | ExpressRoute Gateway |
| `DNSInboundResolverSubnet` | `x.x.x.x/28` | Private DNS Resolver inbound |
| `DNSOutboundResolverSubnet` | `x.x.x.x/28` | Private DNS Resolver outbound |
| `EgressSwgSubnet` | `x.x.x.x/27` | SWG egress NVA |

See [01-landing-zone.md](01-landing-zone.md) for the platform layer detail,
[02-fabric-workload.md](02-fabric-workload.md) and
[03-foundry-workload.md](03-foundry-workload.md) for the workloads.
