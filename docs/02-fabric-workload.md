# 02 — Fabric workload (Layer 2)

A spoke dedicated to **Microsoft Fabric** with private connectivity, peered to
the hub via classic VNet peering and governed by the platform policies.

## Scope

- Fabric spoke VNet (peered to hub, no direct spoke-to-spoke peering).
- Private endpoints / private links for Fabric-facing data services.
- UDR forcing `0.0.0.0/0` through the hub Azure Firewall.
- Diagnostics shipped to the monitor subscription.

## Status

Implementation is split into two Terraform phases around Fabric workspace
creation:

- `workloads/fabric/` creates the F capacity, spoke network, forced-tunnel UDR,
  hub peerings, central diagnostics, and workspace-level Private Link DNS zone.
- `workloads/fabric-private-link/` creates the private workspace's hidden Fabric
  Private Link service, private endpoint, and DNS zone group after the workspace
  ID is known.

The private workspace is locked down only after endpoint approval, private DNS
resolution, and data-plane connectivity have been verified. The public workspace
remains public and is protected with Entra Conditional Access.

## Dependencies

- Requires `platform/20-connectivity-hub` (hub VNet + firewall) and
  `platform/40-monitoring` (Log Analytics workspace).
- Requires the Fabric tenant setting **Configure workspace-level inbound network
  rules** before public access can be denied.
- Requires both workspaces to be assigned to an F SKU capacity.
