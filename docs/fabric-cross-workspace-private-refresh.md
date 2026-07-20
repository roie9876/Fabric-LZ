# Cross-workspace semantic-model refresh into a private Workspace A

## The problem (observed in this lab, 2026-07-20)

After Phase 9 locks **Workspace A** (the private lakehouse workspace) to
*"Allow connections from selected networks and workspace-level private links"*
(inbound public access = **Deny**):

- **Hop 1 — on-prem SQL -> Workspace A** (OPDG copy job): **still works.** The
  gateway reaches Workspace A over its workspace private endpoint.
- **Hop 2 — Workspace A -> Workspace B semantic-model refresh**: **FAILS** with:

  ```
  errorCode: ModelRefresh_ShortMessage_ProcessingError
  code:      CrossWorkspaceRequestNotAllowed
  message:   Access protector failed due to CrossWorkspaceRequestNotAllowed
  ```

  Evidence: `workloads/fabric/evidence/post-lockdown-refresh-CrossWorkspaceRequestNotAllowed.json`

So a public **Workspace B** Import model that reads Workspace A's SQL analytics
endpoint over an ordinary **cloud / Organizational-account** connection can no
longer refresh once Workspace A is private. The report keeps showing the last
pre-lockdown data; it cannot pick up new rows.

## Root cause (Microsoft-documented, by design)

When a workspace restricts inbound public access, Fabric's **access protector**
blocks any request that arrives from **another Fabric workspace** over the cloud
path. A Power BI refresh runs in the Fabric backend and initiates the connection
**from Workspace B's service infrastructure**, so it is classified as a
cross-workspace public request and denied. No credential/cloud-connection change
bypasses this — the network path itself is blocked.

> "By default, a workspace with restricted inbound public access restricts
> connections from other workspaces. To enable cross-workspace communication in
> this scenario, you must use either managed private endpoints or a data
> gateway. These options are necessary even if private endpoints exist between
> the client and one or both workspaces. The reason is that the source workspace
> (not the client) initiates the connection."
> — [Cross-workspace communication](https://learn.microsoft.com/en-us/fabric/security/security-cross-workspace-communication)

Two hard limits make the "obvious" workarounds impossible:

- **You cannot co-locate the semantic model in Workspace A.** Semantic models
  are unsupported in workspaces with workspace-level private links — you cannot
  enable private links on a workspace that contains one.
  [Limitations](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-support)
- **Managed private endpoints do not cover semantic-model refresh** (only
  shortcuts, notebooks, pipelines, eventstreams). Semantic-model refresh must go
  through a **data gateway**.
  [Cross-workspace communication](https://learn.microsoft.com/en-us/fabric/security/security-cross-workspace-communication)

The topology "model in a separate open Workspace B, lakehouse in restricted
Workspace A, bridged by a gateway" is therefore the **mandated** design, not a
workaround.

## The supported fix: bind the model to a gateway with private access to A

Microsoft publishes two step-by-step walkthroughs for exactly this topology:

- VNet data gateway:
  https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-power-bi-virtual-network
- On-premises data gateway (OPDG):
  https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-on-premises-data-gateway

Because this lab already runs an OPDG (`azlab-gateway`) inside the private
network, the OPDG pattern applies.

### Step 1 — Use the workspace-private connection string (mandatory)

The ordinary SQL analytics endpoint host
(`<hash>.datawarehouse.fabric.microsoft.com`) does **not** resolve over
workspace-level private links. You must insert the `z{xy}` segment, where `{xy}`
is the first two characters of Workspace A's object ID:

```
Public  : yzg45hohc3cerh2xkkexzrnism-gpvaziweggiefdfn2z4af3lh5a.datawarehouse.fabric.microsoft.com
Private : yzg45hohc3cerh2xkkexzrnism-gpvaziweggiefdfn2z4af3lh5a.za2.datawarehouse.fabric.microsoft.com
                                                                 ^^^  z + first two chars of workspace ID (a2)
```

Workspace A ID = `a20cea33-...` -> no dashes `a20cea33...` -> `z` + `a2` = `za2`.
Database = the lakehouse name (`lh_onprem_private`) or the lakehouse GUID.

> "You need to add `z{xy}` to the regular warehouse connection string ... This
> FQDN isn't available as part of the DNS configurations for the private
> endpoint."
> — [Workspace-level private links overview](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview#connecting-to-workspaces)

### Step 2 — DNS for the datawarehouse FQDN (the gap in this lab)

The workspace private endpoint auto-registers these A records in
`privatelink.fabric.microsoft.com` (verified in this lab):

| Sub-resource | Private IP |
|---|---|
| `a20cea33...za2.w.api`   | 10.2.0.4 |
| `a20cea33...za2.c`       | 10.2.0.5 |
| `a20cea33...za2.onelake` | 10.2.0.6 |
| `a20cea33...za2.dfs`     | 10.2.0.7 |
| `a20cea33...za2.blob`    | 10.2.0.8 |

There is **no `datawarehouse` record** — matching the doc's warning that the
warehouse FQDN "isn't available as part of the DNS configurations for the
private endpoint." The gateway host must be able to resolve the `za2`
datawarehouse FQDN to the workspace private endpoint. Provide this via the
gateway VNet's DNS (custom record / conditional forwarder) per the official
walkthrough before the connection will succeed.

### Step 3 — Create the gateway SQL connection and bind the model

1. In **Manage connections and gateways**, on the OPDG (or a VNet gateway),
   create a **SQL Server** connection:
   - Server: the `za2` datawarehouse FQDN (Step 1)
   - Database: `lh_onprem_private` (or the lakehouse GUID)
   - Authentication: **Organizational account (OAuth2)**
2. In **Workspace B -> semantic model -> Settings -> Gateway and cloud
   connections**, switch from the cloud connection to the **gateway** connection
   and map the data source.
3. Trigger a refresh. `CrossWorkspaceRequestNotAllowed` should be gone; traffic
   now flows: model (B) -> gateway -> private endpoint -> Workspace A SQL
   analytics endpoint.

### Do NOT use

- **OneLake catalog / Direct Lake** — Direct Lake is not yet supported against
  inbound-restricted workspaces. Use **Import** or **DirectQuery** against the
  SQL analytics endpoint (Import is what this lab uses).
- **Item/app sharing from Workspace A** — unsupported in restricted workspaces.

## Operational implication for the customer

- New on-prem data always reaches **private Workspace A** (hop 1 via OPDG).
- The **public report refreshes only if hop 2 goes through a gateway** with
  private access to A (this fix). Without it, the public report is
  point-in-time as of the last pre-lockdown refresh.
- There is **no tenant admin toggle** that bypasses the access protector.

## References

- Cross-workspace communication — https://learn.microsoft.com/en-us/fabric/security/security-cross-workspace-communication
- Workspace-level private links overview — https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview
- Supported scenarios and limitations — https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-support
- VNet gateway walkthrough — https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-power-bi-virtual-network
- OPDG walkthrough — https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-on-premises-data-gateway
