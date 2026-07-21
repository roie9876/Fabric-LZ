# Stage 20 — Connectivity Hub

The heart of the landing zone. Creates the central Hub & Spoke networking.

## What it creates

| Resource | Purpose |
|---|---|
| Hub VNet + subnets | `AzureFirewallSubnet`, DNS Resolver in/out, SWG egress, dedicated Azure Monitor private endpoint `/27` |
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

> **Greenfield ordering:** first apply this stage with
> `enable_fw_diagnostics = false` to create the hub and
> `AzureMonitorPrivateEndpointSubnet`. Apply `40-monitoring` next to create the
> workspace, AMPLS, private endpoint, and DNS. Finally, re-apply this stage with
> `enable_fw_diagnostics = true`. Existing environments that already have the
> workspace can add the subnet without disabling diagnostics.

## Outputs consumed by workloads

- `hub_vnet_id`, `monitor_private_endpoint_subnet_id`,
  `firewall_private_ip`, `dns_inbound_endpoint_ip`.

## Not yet included (extend as needed)

- Workload-specific private DNS zones. Azure Monitor zones are centrally owned
	by `40-monitoring` and linked to this hub.
