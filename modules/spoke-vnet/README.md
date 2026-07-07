# `modules/spoke-vnet`

Reusable spoke virtual network for a workload: VNet, subnets, classic hub
peering, and the platform's forced-tunnel UDR (`0.0.0.0/0` → firewall).

> Skeleton placeholder. Inputs will include: `address_space`, `subnets`,
> `hub_vnet_id`, `firewall_private_ip`.

Depends on `platform/20-connectivity-hub` outputs (hub VNet id, firewall IP).
