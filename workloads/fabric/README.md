# Workload — Fabric (Layer 2)

Spoke for **Microsoft Fabric** with private connectivity, peered to the hub
(classic peering + UDR) and governed by the platform policies.

## Topology (target)

![Microsoft Fabric — workspace-level Private Link](../../docs/images/05-fabric-private-link.png)

This is the target access model — **workspace-level Private Link** for private,
per-workspace inbound access to Fabric. Reading it left to right:

- **Sources (left).** Clients reach Fabric from **on-prem** (over **ExpressRoute
  / VPN**) and from **Azure VNets** (over **peering**). In our LZ these all route
  through the hub, so the "Customer VNet" is simply the **Fabric spoke**.
- **Customer VNet (Fabric spoke).** A **Private Endpoint** for the Fabric
  workspace lives in the spoke's **pe-subnet**. A user in (or routed to) this
  VNet reaches Fabric through that private IP — never the public internet.
- **Azure Private Link (Workspace Level).** The private endpoint is scoped to a
  **specific workspace** (not the whole tenant), so you control inbound access
  per workspace.
- **Fabric Tenant.**
  - **Workspace A** — **public access Disabled**. Reachable **only** through the
    private endpoint. Holds Lakehouse, Warehouse, Notebook, **OneLake**, and
    Spark Job Definitions. *Note:* enabling private link + block-public forces
    workspace **Spark into a managed VNet** (starter pools disabled, slower
    session start).
  - **Workspace B** — **public access Enabled**, but gated by **Entra
    Conditional Access** at the **tenant level** (a portal/API user must satisfy
    CA policy). Holds Semantic Model, Report, Pipeline, KQL Database.
  - **Secure Data Access** — workspaces exchange data over Fabric's internal
    secure path.
- **Two inbound postures side by side.** Workspace A = **network isolation**
  (private endpoint, no public); Workspace B = **identity isolation** (public
  endpoint + Conditional Access). Real tenants often mix both.

How this maps to the LZ: the Private Endpoint sits in the Fabric spoke's
`pe-subnet`; the Fabric/OneLake **private-DNS zones** live in the hub and are
linked to the spoke; **on-prem conditional-forwards** to the hub Private DNS
Resolver so the Fabric FQDNs resolve to the private-endpoint IPs (not public).

## Build order

Requires Layer 1: `platform/20-connectivity-hub` and `platform/40-monitoring`.

## Planned contents

- Fabric spoke VNet (via `modules/spoke-vnet`) joined to the AVNM `spokes` group.
- Private endpoints / private links for Fabric-facing services.
- UDR forcing `0.0.0.0/0` → hub firewall (via `modules/udr`).
- Diagnostics to the central Log Analytics workspace.

> Skeleton placeholder — Terraform to be added as the Fabric layer is built out.
> See [docs/02-fabric-workload.md](../../docs/02-fabric-workload.md).

## Decided target (Layer 2)

**Access to Fabric — workspace-level Private Link (inbound).**
Fabric workspace exposed via an **Azure Private Endpoint** in the Fabric spoke's
`pe-subnet`; workspace **public access Disabled**. Reached privately from:
- **on-prem** (a remote VNet joined to the hub by **S2S VPN** in the lab, **ExpressRoute** in the customer env), and
- **Azure VNets** via hub-spoke peering.

**On-prem SQL → OneLake ingestion — Pattern 2: On-premises Data Gateway (OPDG).**
- A Windows VM running the **OPDG** sits **next to the SQL Server VM in the on-prem VNet**.
- SQL read is **local** (gateway + SQL in the same on-prem VNet).
- The gateway writes to **Fabric / OneLake via the private endpoints**, so that
  data leg travels: on-prem → **S2S VPN / ER** → hub → spoke PE. **This leg
  crosses the ER**, provided DNS resolves Fabric/OneLake FQDNs to the
  private-endpoint IPs.

### Accepted caveat
The OPDG keeps a **mandatory control/registration channel to Azure Relay
(`*.servicebus.windows.net`)** that historically uses **public** endpoints. So
the *data* path crosses the ER, but the gateway's *control* channel still
**egresses** (through the hub firewall / SWG). Confirm current OPDG + private-link
support in-tenant; the control channel may not be fully forceable onto private link.

### Must be correct for this to work
- **DNS:** Fabric/OneLake private-DNS zones in the hub (e.g.
  `privatelink.analysis.windows.net`, `privatelink.pbidedicated.windows.net`,
  `privatelink.prod.powerquery.microsoft.com`, `privatelink.dfs.fabric.microsoft.com`),
  linked to the spoke; the **on-prem gateway VM must conditional-forward** to the
  hub Private DNS Resolver so those names resolve to the PE IPs (not public).
- **Firewall egress (gateway VM):** allow the OPDG relay/auth FQDNs
  (`*.servicebus.windows.net`, `login.microsoftonline.com`, Fabric backend FQDNs).
- **Spark:** enabling private link + block-public forces workspace Spark into a
  **managed VNet with managed private endpoints** (starter pools disabled, slower
  session start).

### Lab build (when we start Layer 2)
- `workloads/onprem-lab/` — on-prem VNet + **SQL Server VM** + **OPDG VM** +
  **dual S2S VPN with BGP** to the hub (ER stand-in). **Lab only.**
- `workloads/fabric/` — Fabric spoke + workspace Private Endpoint + Lakehouse +
  OPDG connection + Copy pipeline into OneLake.
- Note: gateway registration + several Fabric artifacts are tenant-scoped /
  click-through → runbook, not fully Terraformable.
