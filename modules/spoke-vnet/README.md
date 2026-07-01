# `modules/spoke-vnet`

Reusable spoke virtual network for a workload: VNet, subnets, hub peering, and
association to the platform's forced-tunnel UDR and AVNM network group.

> Skeleton placeholder. Inputs will include: `address_space`, `subnets`,
> `hub_vnet_id`, `firewall_private_ip`, `avnm_network_group_id`.

Depends on `platform/20-connectivity-hub` outputs (hub VNet id, firewall IP,
AVNM ids).
