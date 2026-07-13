# Deployment Guide

This is the operator walkthrough for deploying and testing the Fabric landing
zone lab. Follow it from top to bottom. It tells you **where** each action runs,
**when** Terraform stops for a portal action, what evidence to capture, and what
must pass before continuing.

For architecture detail and the full as-built record, see
[workloads/fabric/README.md](workloads/fabric/README.md). That runbook remains
the source of truth when this quick guide and the implementation differ.

## Legend

| Label | Run from | Meaning |
|---|---|---|
| **LAPTOP** | Local terminal | Azure CLI control-plane command |
| **RUNNER** | Private runner VM | Terraform command with managed identity |
| **PORTAL** | Azure, Entra, or Fabric portal | Manual operator action; capture evidence |
| **API** | Laptop or runner | Fabric/Azure API action; record request result |
| **CHECK** | Named host | Read-only validation |
| **STOP** | Operator decision | Do not continue until the stated evidence passes |

## Current checkpoint

As of **2026-07-13**:

- Platform foundation: deployed.
- Fabric Phase A: deployed and converged.
- Private and public Fabric workspaces: created on F2.
- Fabric Phase B workspace Private Link: deployed and converged.
- SQL and OPDG lab VMs: deployed and validated.
- Next deployment action: **Phase 5, interactive OPDG installation and
  registration**.
- Cost-control state: F2 is `Paused`, all six subscription VMs are
  `VM deallocated`, and the unrelated Container App has no active revision.
- Workspace A public access is still `Allow`. Do not restrict it yet.

## Execution model

Terraform state is private. Terraform runs on
`azr-sbx-lab-0001-vm-onprem-runner`, not on the laptop. The laptop starts the
runner and invokes it with Azure VM Run Command.

The three Layer 2 Terraform roots use independent state keys:

| Terraform root | State key |
|---|---|
| `workloads/fabric` | `workloads-fabric.tfstate` |
| `workloads/fabric-private-link` | `workloads-fabric-private-link.tfstate` |
| `workloads/onprem-lab` | `workloads-onprem-lab.tfstate` |

Never combine these states. Never put passwords, access tokens, recovery keys,
private tfvars, Terraform plans, or state files in Git or screenshots.

### How to execute a RUNNER block

Start the runner, make sure `/home/azureuser/lz` contains the intended commit,
then use this pattern from the laptop. Replace the IDs and the Terraform root;
keep credentials out of the command.

```bash
SUBSCRIPTION_ID=<subscription-id>
TENANT_ID=<tenant-id>
RUNNER_RG=azr-sbx-lab-0001-rg-onprem-sim
RUNNER_VM=azr-sbx-lab-0001-vm-onprem-runner
TERRAFORM_ROOT=workloads/fabric

az vm start \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RUNNER_RG" \
  --name "$RUNNER_VM"

az vm run-command invoke \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RUNNER_RG" \
  --name "$RUNNER_VM" \
  --command-id RunShellScript \
  --scripts "set -e
export HOME=/home/azureuser
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
export ARM_TENANT_ID=$TENANT_ID
cd /home/azureuser/lz/$TERRAFORM_ROOT
terraform init -reconfigure -backend-config=../../_private/backend.hcl
terraform validate
terraform plan -var-file=../../_private/lab.private.tfvars -out=deployment.tfplan
terraform show -no-color deployment.tfplan"
```

Review the plan before running a second invocation that applies the saved plan.
Do not combine plan and apply when a stop gate requires human approval.

## Timeline

### 1. Prepare the operator workstation

**LAPTOP**

```bash
az login --tenant <tenant-id>
az account set --subscription <subscription-id>
terraform version
bash scripts/check-sensitive.sh
```

Create the private overlay from the examples and fill in environment-specific
values. `_private/` is ignored by Git.

```bash
cp _private/denylist.txt.example _private/denylist.txt
cp _private/enterprise.tfvars.example _private/lab.private.tfvars
```

The initial bootstrap creates the state storage account. Create
`_private/backend.hcl` from those bootstrap outputs as described by the
bootstrap workflow; there is deliberately no committed backend template with
live storage details.

The current lab already has its private overlay and backend configuration. Do
not overwrite them when resuming.

### 2. Deploy Layer 1 once

Skip this section when resuming the current lab. The implemented platform roots
were deployed in this order:

1. `platform/00-bootstrap`
2. `platform/10-management-groups`
3. `platform/20-connectivity-hub`
4. `platform/40-monitoring`

`platform/30-egress` and `platform/50-security` are currently design stubs, not
completed deployment stages.

For each implemented root, run **RUNNER**:

```bash
cd /home/azureuser/lz/<terraform-root>
terraform init -backend-config=../../_private/backend.hcl
terraform validate
terraform plan -var-file=../../_private/lab.private.tfvars -out=stage.tfplan
terraform show -no-color stage.tfplan
terraform apply stage.tfplan
terraform plan -detailed-exitcode -var-file=../../_private/lab.private.tfvars
```

Expected final detailed exit code: `0` (`No changes`). Review
[platform/DEPLOYMENT.md](platform/DEPLOYMENT.md) for Layer 1 screenshots and the
as-built inventory.

**STOP:** the hub VNet, Azure Firewall, DNS Resolver, monitoring workspace, and
hybrid gateway path must be healthy before Layer 2.

### 3. Start or resume the Layer 2 lab

For the current paused checkpoint, run **LAPTOP**:

```bash
SUBSCRIPTION_ID=<subscription-id>
RESOURCE_GROUP=azr-sbx-lab-0001-rg-onprem-sim

az rest --method post \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/azr-sbx-lab-0001-rg-fabric-spoke/providers/Microsoft.Fabric/capacities/azrsbxlab0001fabcap/resume?api-version=2023-11-01"

for vm_name in \
  azr-sbx-lab-0001-vm-onprem-runner \
  azr-sbx-lab-0001-vm-onprem-sql \
  azr-sbx-lab-0001-vm-onprem-opdg
do
  az vm start \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$vm_name"
done
```

Start `onprem-vm` only when a separate network test host is needed.

**CHECK**

```bash
az vm list -d --subscription "$SUBSCRIPTION_ID" \
  --query '[?resourceGroup==`AZR-SBX-LAB-0001-RG-ONPREM-SIM`].{name:name,power:powerState}' \
  -o table
```

Expected: the runner, SQL, and OPDG VMs are `VM running`; F2 is `Active`.

### 4. Complete Fabric tenant prerequisites

Skip this section when resuming the current lab; it is complete.

**PORTAL: Microsoft Entra admin center**

1. Open **Identity governance** > **Privileged Identity Management** >
   **Microsoft Entra roles**.
2. Assign or activate **Fabric Administrator** for the operator.
3. Complete the wizard, then sign out of Fabric and sign in again.
4. Evidence: `workloads/fabric/images/fabric admin role in entra.jpeg`.

**PORTAL: Microsoft Fabric**

1. Open **Settings** > **Admin portal** > **Tenant settings**.
2. Under **Advanced networking**, open **Configure workspace-level inbound
   network rules**.
3. Enable it for the entire organization and select **Apply**.
4. Refresh the page and verify there are no unapplied changes.
5. Evidence:
   - `01-open-admin-portal.png.jpeg`
   - `workspace level rule.jpeg`
   - `workspace-level-rule-applied.jpeg`

**LAPTOP**

```bash
az provider register \
  --namespace Microsoft.Fabric \
  --subscription "$SUBSCRIPTION_ID" \
  --wait
```

**STOP:** the setting must remain enabled after refresh and the provider must
report `Registered`.

### 5. Terraform Phase A: Fabric foundation

Skip this section when resuming the current lab; it is complete and had no
drift before shutdown.

Phase A creates the F2 capacity, Fabric spoke, private-endpoint subnet, route
table, hub peerings, diagnostics, and `privatelink.fabric.microsoft.com` zone.

**RUNNER**

```bash
cd /home/azureuser/lz/workloads/fabric
terraform init -backend-config=../../_private/backend.hcl
terraform validate
terraform plan \
  -var-file=../../_private/lab.private.tfvars \
  -out=phase-a.tfplan
terraform show -no-color phase-a.tfplan
terraform apply phase-a.tfplan
terraform plan \
  -detailed-exitcode \
  -var-file=../../_private/lab.private.tfvars
```

First deployment expectation: `13 added, 0 changed, 0 destroyed`.
Final expectation: exit code `0`, no drift.

No portal screenshot is required for this Terraform-only phase. Record the plan,
apply summary, and read-only Azure checks in the runbook.

### 6. Create both Fabric workspaces

Skip this section when resuming the current lab; it is complete.

**PORTAL: Microsoft Fabric**

Create Workspace A:

1. Open **Workspaces** > **New workspace**.
2. Name it `azr-sbx-lab-0001-fabws-private`.
3. Assign it to `azrsbxlab0001fabcap` (`F2`, Israel Central).
4. Keep public access enabled during deployment.
5. Evidence: screenshots `03` through `06` in
   `workloads/fabric/images/`.

Create Workspace B:

1. Create `azr-sbx-lab-0001-fabws-public`.
2. Assign it to the same F2 capacity.
3. Keep public access enabled; Entra Conditional Access protects this workspace.
4. Evidence: screenshots `07` and `08`.

Record both workspace IDs and the capacity ID. Add only Workspace A's ID to the
private tfvars file:

```hcl
fabric_private_workspace_id = "<workspace-a-object-id>"
```

**STOP:** both workspaces must show the saved names and F2 assignment after a
page refresh.

### 7. Grant the runner Fabric workspace lifecycle access

Skip this section when resuming the current lab; it is complete.

**API**

The runner managed identity needs both Azure Contributor permissions and Fabric
Workspace A `Admin`. Use a signed-in Fabric Administrator to add the runner's
service principal through the Fabric workspace role-assignment API. Record the
HTTP result and read the assignment back. Do not record the bearer token.

Retain this assignment. Terraform needs it to update or destroy the hidden
workspace Private Link service later.

**STOP:** read-back must show the runner service principal as Workspace A
`Admin`.

### 8. Terraform Phase B: workspace Private Link

Skip this section when resuming the current lab; it is complete and had no
drift before shutdown.

**RUNNER**

```bash
cd /home/azureuser/lz/workloads/fabric-private-link
terraform init -backend-config=../../_private/backend.hcl
terraform validate
terraform plan \
  -var-file=../../_private/lab.private.tfvars \
  -out=phase-b.tfplan
terraform show -no-color phase-b.tfplan
terraform apply phase-b.tfplan
terraform plan \
  -detailed-exitcode \
  -var-file=../../_private/lab.private.tfvars
```

First deployment expectation: `2 added, 0 changed, 0 destroyed`.
Final expectation: exit code `0`, no drift.

**CHECK: on-prem test VM or OPDG VM**

Verify the five Workspace A FQDNs resolve to the private endpoint IPs and accept
TCP 443:

| Endpoint | Expected IP |
|---|---|
| Workspace API | `10.2.0.4` |
| Control | `10.2.0.5` |
| OneLake | `10.2.0.6` |
| DFS | `10.2.0.7` |
| Blob | `10.2.0.8` |

Also verify an authenticated Workspace A API request returns HTTP `200` through
`10.2.0.4`. Never print the access token.

**STOP:** keep Workspace A public access enabled if DNS, routing, endpoint
approval, TCP 443, or authenticated API validation fails.

### 9. Terraform Phase 4: simulated on-prem SQL and OPDG hosts

Skip this section when resuming the current lab; it is complete and had no
drift before shutdown.

**RUNNER**

```bash
cd /home/azureuser/lz/workloads/onprem-lab
terraform init -backend-config=../../_private/backend.hcl
terraform validate
terraform plan \
  -var-file=../../_private/lab.private.tfvars \
  -out=onprem-lab.tfplan
terraform show -no-color onprem-lab.tfplan
terraform apply onprem-lab.tfplan
terraform plan \
  -detailed-exitcode \
  -var-file=../../_private/lab.private.tfvars
```

A new environment creates 14 resources. The final plan must return exit code
`0`.

**CHECK**

- SQL VM: `172.16.1.10`, SQL Server listening on TCP 1433.
- OPDG VM: `172.16.1.11`.
- SQL authentication reads exactly three `dbo.SalesOrders` rows.
- OPDG reaches SQL TCP 1433.
- OPDG resolves and reaches all five private Fabric endpoints on TCP 443.
- `C:\FabricHybridLab.ready` contains `SQL_READY`.
- `C:\FabricGatewayInstaller.ready` exists.
- `C:\Installers\GatewayInstall.exe` exists.

Terraform stages the official gateway installer. It does not perform the
user-authenticated gateway registration.

### 10. Phase 5: install and register OPDG

This is the **next action for the current lab**.

**PORTAL / OPDG VM interactive session**

1. On the OPDG VM, run `C:\Installers\GatewayInstall.exe` as Administrator.
2. Keep the default installation path, accept the terms, and select **Install**.
3. Sign in with the Fabric gateway administrator organizational account.
4. Select **Register a new gateway on this computer**.
5. Name it `azr-sbx-lab-0001-opdg` in standard mode.
6. Generate a strong recovery key outside Terraform.
7. Store the recovery key in the approved secret manager. Microsoft cannot
   recover it.
8. In Fabric, open **Settings** > **Manage connections and gateways**.
9. Verify the cluster and member are **Online**.

Required screenshots:

- `09-opdg-installer-complete.jpeg`
- `10-opdg-cluster-registered.jpeg`
- `11-opdg-cluster-online.jpeg`

Never show the recovery key, password, token, or connection secret.

**STOP:** do not continue until the cluster is Online and all three screenshots
are linked in [workloads/fabric/README.md](workloads/fabric/README.md).

### 11. Phase 6: create the private lakehouse and ingest SQL

**PORTAL: Workspace A**

1. Create lakehouse `lh_onprem_private`.
2. Create an SQL Server connection through `azr-sbx-lab-0001-opdg`:
   - Server: `172.16.1.10`
   - Database: `FabricHybridLab`
   - Authentication: Basic
   - User: `fabric_gateway`
   - Password: retrieve privately from Terraform output
3. Create pipeline `pl_sql_to_onelake_private`.
4. Copy `dbo.SalesOrders` to the lakehouse as a Delta table.
5. Run the pipeline and verify three rows.

Required screenshots:

- `12-private-lakehouse-created.jpeg`
- `13-opdg-sql-connection-online.jpeg`
- `14-copy-pipeline-succeeded.jpeg`
- `15-lakehouse-salesorders-data.jpeg`

Record the lakehouse, SQL analytics endpoint, pipeline, and connection IDs.

**STOP:** ingestion must pass before Workspace A public access is restricted.

### 12. Phase 7: build the public semantic model and report

**PORTAL: Workspace B**

1. Create an Import or DirectQuery semantic model against Workspace A's SQL
   analytics endpoint through OPDG.
2. Bind the model to the approved gateway connection.
3. Refresh the model.
4. Create a report that displays the three orders.

Required screenshots:

- `16-public-semantic-model-gateway-binding.jpeg`
- `17-public-semantic-model-refresh-succeeded.jpeg`
- `18-public-report-salesorders.jpeg`

**STOP:** gateway binding and refresh must succeed before lockdown.

### 13. Phase 8: final pre-lockdown validation

**CHECK**

- Five Workspace A FQDNs resolve to `10.2.0.4` through `10.2.0.8` from OPDG.
- TCP 443 succeeds to all five endpoints.
- OPDG reaches SQL TCP 1433 and queries three rows.
- Authenticated Workspace A API request returns HTTP `200` privately.
- Copy pipeline succeeds through OPDG.
- Workspace B semantic-model refresh succeeds through OPDG.
- Workspace A and B still report inbound/outbound public access `Allow`.

**STOP:** any failure keeps Workspace A public access enabled.

### 14. Phase 9: restrict Workspace A last

**PORTAL: Workspace A**

1. Open **Workspace settings** > **Inbound networking**.
2. Select **Allow connections from selected networks and workspace level
   private links**.
3. Select **Apply** and wait up to 30 minutes.
4. Refresh and capture `19-private-workspace-inbound-restricted.jpeg`.
5. Repeat every Phase 8 private and gateway test.
6. Verify a public request to Workspace A is denied.
7. Verify Workspace B remains publicly reachable under Entra Conditional
   Access.

Rollback: restore `publicAccessRules.defaultAction` to `Allow`, then diagnose
DNS, endpoint, routing, gateway, and item compatibility before retrying.

### 15. Pause the lab when idle

**LAPTOP**

1. Confirm no pipeline, refresh, Spark job, or interactive user is active.
2. Pause F2.
3. Deallocate the runner, SQL, OPDG, and optional test VM.
4. Verify all VM states and the capacity state.

```bash
az rest --method post \
  --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/azr-sbx-lab-0001-rg-fabric-spoke/providers/Microsoft.Fabric/capacities/azrsbxlab0001fabcap/suspend?api-version=2023-11-01"

for vm_name in \
  azr-sbx-lab-0001-vm-onprem-runner \
  azr-sbx-lab-0001-vm-onprem-sql \
  azr-sbx-lab-0001-vm-onprem-opdg \
  onprem-vm
do
  az vm deallocate \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$vm_name" \
    --no-wait
done
```

Pausing F2 stops Fabric compute billing. VM deallocation stops VM compute
billing. Azure Firewall, VPN gateways, NAT Gateway, disks, public IPs, Private
Endpoints, DNS, state storage, and OneLake storage continue to incur charges.

## Evidence index

| Evidence | Location |
|---|---|
| Layer 1 screenshots and inventory | [platform/DEPLOYMENT.md](platform/DEPLOYMENT.md) |
| Fabric portal screenshots | `workloads/fabric/images/` |
| Fabric full runbook and API evidence | [workloads/fabric/README.md](workloads/fabric/README.md) |
| Architecture diagrams | `docs/diagrams/` and `docs/images/` |
| Terraform validation | Run in each Terraform root before plan/apply |
| Secrets check | `bash scripts/check-sensitive.sh` |

## Resume marker

When returning to this deployment, begin at **Step 3**, verify the resumed
resources, then continue at **Step 10**. Do not repeat completed portal or
Terraform phases unless a read-only check or Terraform plan shows drift.
