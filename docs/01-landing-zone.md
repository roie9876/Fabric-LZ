# 01 — Platform (Landing Zone foundation)

Layer 1 builds the shared foundation every workload depends on. It is deployed
once, in stage order.

## Stages

| Stage | Folder | Creates |
|---|---|---|
| 00 | `platform/00-bootstrap` | Remote state backend, provider config, CI (OIDC) identity |
| 10 | `platform/10-management-groups` | `mgmt` / `workloads` / `monitor` / `sandbox` hierarchy + subscription placement |
| 20 | `platform/20-connectivity-hub` | Hub VNet, Azure Firewall + Policy, ExpressRoute GW, DDoS plan, Private DNS Resolver |
| 30 | `platform/30-egress` | Secure egress: UDR `0.0.0.0/0` → SWG NVA (vendor-agnostic) |
| 40 | `platform/40-monitoring` | Log Analytics, AMPLS, Action Groups, DCR, alerts, workbooks |
| 50 | `platform/50-security` | Defender for Cloud plans + CNAPP onboarding hooks |

## Deployment order

```
00-bootstrap → 10-management-groups → 20-connectivity-hub → 30-egress → 40-monitoring → 50-security
```

## Key decisions

- **Classic peering + UDR** — each workload spoke peers to the hub and applies
  its own forced-tunnel route table (`0.0.0.0/0` → firewall). No AVNM.
- **Azure Firewall** is the single inspection point for east-west and on-prem.
- **Egress** is forced to a 3rd-party SWG; the module takes the NVA private IP
  and FQDN allow-lists as input, so no brand is hard-coded.
- **Monitoring** is centralized in a dedicated subscription; workloads ship
  diagnostics there.

Each stage folder has its own `README.md`, `versions.tf`, `variables.tf`,
`main.tf`, and `outputs.tf`.
