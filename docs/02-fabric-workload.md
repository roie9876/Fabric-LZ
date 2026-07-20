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

## Known behaviors after locking down the private workspace

Two behaviors were observed and verified in the reference lab (2026-07-20). Both
are covered in detail, with the supported fix and Microsoft citations, in
[fabric-cross-workspace-private-refresh.md](fabric-cross-workspace-private-refresh.md).

1. **Cross-workspace semantic-model refresh is blocked by default.** Once the
   private workspace denies inbound public access, a semantic model in the public
   workspace that reads the private lakehouse's SQL analytics endpoint over an
   ordinary cloud connection fails to refresh with
   `CrossWorkspaceRequestNotAllowed` (Fabric's "access protector"). The model
   must instead be bound to a **data gateway** (the OPDG or a VNet gateway) using
   the workspace-private `z{xy}` datawarehouse FQDN. Semantic models cannot be
   co-located in the private workspace (they are unsupported with workspace-level
   private links), and Direct Lake is not yet supported against restricted
   workspaces — use Import or DirectQuery.

2. **SQL analytics endpoint metadata sync lag.** The public Import model reads
   through the lakehouse's **SQL analytics endpoint**, which is a separate engine
   that trails the OneLake Delta store by a few minutes. Immediately after a copy
   job writes new rows, the first model refresh can still return the previous row
   set; a second refresh after the endpoint metadata syncs returns the new rows.
   When automating, schedule the model refresh a few minutes after the copy job
   (or add an explicit metadata-sync step).

Also note: after lockdown, **control-plane job triggers for the private workspace
must originate from inside the allowed VNet** (or run as a schedule in the Fabric
backend). Public-client API/portal calls to run jobs in the private workspace are
denied by the inbound policy (`RequestDeniedByInboundPolicy`).
