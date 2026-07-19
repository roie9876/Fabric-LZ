# Stage 20 — Connectivity Hub

The heart of the landing zone. Creates the central Hub & Spoke networking.

## What it creates

| Resource | Purpose |
|---|---|
| Hub VNet + subnets | `AzureFirewallSubnet`, DNS Resolver in/out, SWG egress |
| Azure Firewall + Policy | Single inspection point for east-west and on-prem traffic |
| DDoS Protection plan | Protects hub public IPs (toggle with `enable_ddos`) |
| Private DNS Resolver | Inbound + outbound endpoints for hybrid DNS |

> **Connectivity model:** classic VNet peering + per-spoke UDR (no AVNM). Each
> workload spoke peers to this hub and forces `0.0.0.0/0` to the firewall.

## Deploy

```bash
cd platform/20-connectivity-hub
terraform init -backend-config=../../_private/backend.hcl
terraform apply -var-file=../../_private/enterprise.private.tfvars
```

> **Ordering:** the firewall diagnostic setting references the `40-monitoring`
> Log Analytics workspace. Apply `40-monitoring` **before** this stage, or set
> `enable_fw_diagnostics = false` for the first apply and re-apply as `true` once
> monitoring exists. Everything else in this stage is independent.

## Outputs consumed by workloads

- `hub_vnet_id`, `firewall_private_ip`, `dns_inbound_endpoint_ip`.

## Not yet included (extend as needed)

- Private DNS zones for private endpoints (can live here or in a dedicated DNS stage).
