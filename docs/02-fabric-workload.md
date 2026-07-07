# 02 — Fabric workload (Layer 2)

A spoke dedicated to **Microsoft Fabric** with private connectivity, peered to
the hub via classic VNet peering and governed by the platform policies.

## Scope

- Fabric spoke VNet (peered to hub, no direct spoke-to-spoke peering).
- Private endpoints / private links for Fabric-facing data services.
- UDR forcing `0.0.0.0/0` through the hub Azure Firewall.
- Diagnostics shipped to the monitor subscription.

## Status

Skeleton only. See `workloads/fabric/` for the Terraform entry point. Detailed
private-connectivity design will be added as the Fabric layer is built out.

## Dependencies

- Requires `platform/20-connectivity-hub` (hub VNet + firewall) and
  `platform/40-monitoring` (Log Analytics workspace).
