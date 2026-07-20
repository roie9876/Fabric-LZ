# Fabric workload (Layer 2)

This directory contains the Terraform foundation for the Microsoft Fabric
workload spoke. It implements the Azure resources required for workspace-level
Private Link, forced routing through the hub firewall, private DNS integration,
and Fabric capacity.

> **Deployment authority:** Follow
> [../../DEPLOYMENT-GUIDE.md](../../DEPLOYMENT-GUIDE.md) for the executable
> customer deployment sequence, portal steps, validation gates, rollback, and
> evidence requirements. This README describes the module; it is not a second
> runbook.

## Start here

| Need | Document |
|---|---|
| Deploy the solution | [Customer Deployment Guide](../../DEPLOYMENT-GUIDE.md) |
| Understand the Fabric topology | This README |
| Review the completed reference lab | [REFERENCE-LAB.md](REFERENCE-LAB.md) |
| Troubleshoot post-lockdown refresh | [Cross-workspace private refresh](../../docs/fabric-cross-workspace-private-refresh.md) |
| Reproduce firewall rules | [OPDG and Fabric firewall rules](../../docs/fabric-opdg-firewall-rules.md) |
| Review Layer 1 dependencies | [Platform README](../../platform/README.md) |

## Topology

![Microsoft Fabric workspace-level Private Link](../../docs/images/05-fabric-private-link.png)

The design uses two Fabric workspaces with different inbound postures:

- **Workspace A (private):** Hosts the lakehouse and ingestion workloads. Public
  inbound access is disabled after validation, and clients reach the workspace
  through its workspace-level private endpoint.
- **Workspace B (public):** Hosts the semantic model and report. Public access
  remains enabled and must be protected by approved tenant-level identity
  controls such as Entra Conditional Access.
- **Cross-workspace refresh:** After Workspace A is restricted, Workspace B
  refreshes through an approved data gateway connection to Workspace A's
  workspace-private SQL analytics endpoint.

The private endpoint is placed in the Fabric spoke. Private DNS zones are owned
by the hub and linked to the hub and spoke. On-premises DNS forwards Fabric
queries to the hub Private DNS Resolver. Routes force workload and on-premises
traffic through Azure Firewall.

## Implementation boundary

The workload is split into two Terraform roots because the workspace Private
Link resource requires a Fabric workspace object ID that is available only
after the workspace is created in the Fabric control plane.

### Phase A: `workloads/fabric`

Creates:

- Fabric workload resource group.
- Fabric spoke VNet and private-endpoint subnet.
- Default and on-premises return routes through the hub firewall.
- Bidirectional hub/spoke VNet peerings.
- `privatelink.fabric.microsoft.com` private DNS zone and VNet links.
- Microsoft Fabric capacity.
- Spoke VNet diagnostics.

### Fabric control-plane stop gate

The operator creates Workspace A and Workspace B, assigns both to the capacity,
records Workspace A's object ID, and grants the deployment identity the required
workspace role. These actions and their acceptance criteria are documented in
the [deployment guide](../../DEPLOYMENT-GUIDE.md).

### Phase B: `workloads/fabric-private-link`

Creates:

- Workspace-level Fabric Private Link service for Workspace A.
- Private endpoint in the Fabric spoke.
- Private DNS zone group.
- Read-back outputs for the workspace API FQDN and endpoint IPs.

Do not combine the roots or use Terraform targeting to bypass the workspace-ID
dependency.

## Dependencies

- `platform/20-connectivity-hub`: hub VNet, Azure Firewall, Firewall Policy, and
  Private DNS Resolver.
- `platform/40-monitoring`: central Log Analytics workspace.
- Fabric tenant setting **Configure workspace-level inbound network rules**.
- Fabric Administrator access for tenant and workspace prerequisites.
- An approved F SKU and region.
- Private Terraform state reachable from the deployment runner.

The current release is validated in the repository's supported
single-subscription topology. See the deployment guide's release boundary before
adapting it to a multi-subscription customer design.

## Configuration

Phase A consumes:

- Subscription and tenant identifiers.
- Naming tokens: `env`, `org`, and subscription short codes.
- Azure region.
- Fabric spoke and private-endpoint subnet CIDRs.
- On-premises source CIDR and return-routing behavior.
- Fabric capacity SKU and administrator UPN.

Phase B consumes the same workload naming and identity values plus
`fabric_private_workspace_id`.

Keep real identifiers, address plans, and environment values in the ignored
private overlay. See [../../docs/PUBLISHING.md](../../docs/PUBLISHING.md).

## Outputs

Phase A exports:

- `fabric_spoke_vnet_id`
- `pe_subnet_id`
- `fabric_capacity_id`
- `fabric_capacity_name`
- `workspace_private_dns_zone_id`
- `workspace_private_dns_zone_name`

Phase B exports:

- `workspace_private_link_service_id`
- `workspace_private_endpoint_id`
- `workspace_private_endpoint_ips`
- `workspace_api_fqdn`

## Operational behavior

The following verified behaviors affect the final design:

- Direct cloud refresh from Workspace B to a restricted Workspace A fails with
  `CrossWorkspaceRequestNotAllowed`; bind the model to an approved gateway using
  the workspace-private SQL analytics endpoint.
- The lakehouse SQL analytics endpoint can lag behind the OneLake Delta store;
  schedule model refresh after metadata synchronization.
- Private-workspace job control must originate from an allowed network path or a
  supported Fabric schedule after public inbound access is denied.

See
[Cross-workspace refresh after private-workspace lockdown](../../docs/fabric-cross-workspace-private-refresh.md)
for the validated solution and evidence.

## Reference evidence

The completed lab timeline, portal screenshots, API evidence, applied-state
checks, and historical phase notes are retained in
[REFERENCE-LAB.md](REFERENCE-LAB.md). Screenshot files remain in
[`images/`](images/) and API evidence remains in [`evidence/`](evidence/).

Customer deployments must capture their own evidence according to the
[deployment guide](../../DEPLOYMENT-GUIDE.md); the repository images are
reference examples only.
