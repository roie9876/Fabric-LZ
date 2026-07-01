# Stage 20 — Connectivity Hub

The heart of the landing zone. Creates the central Hub & Spoke networking.

## What it creates

| Resource | Purpose |
|---|---|
| Hub VNet + subnets | `AzureFirewallSubnet`, `GatewaySubnet`, DNS Resolver in/out, SWG egress |
| Azure Firewall + Policy | Single inspection point for east-west and on-prem traffic |
| DDoS Protection plan | Protects hub public IPs (toggle with `enable_ddos`) |
| Private DNS Resolver | Inbound + outbound endpoints for hybrid DNS |
| Azure Virtual Network Manager | Hub & Spoke connectivity + security admin rules |
| AVNM `spokes` network group | Spokes (Fabric, Foundry) join this group |

## Deploy

```bash
cd platform/20-connectivity-hub
terraform init -backend-config=../../_private/backend.hcl
terraform apply -var-file=../../_private/enterprise.private.tfvars
```

## Outputs consumed by workloads

- `hub_vnet_id`, `firewall_private_ip`, `avnm_spokes_network_group_id`,
  `dns_inbound_endpoint_ip`.

## Not yet included (extend as needed)

- ExpressRoute Gateway + connection (add in `GatewaySubnet`).
- Firewall rule collection groups (application/network rules).
- AVNM connectivity + security-admin configurations and deployments.
- Private DNS zones for private endpoints (can live here or in a dedicated DNS stage).
