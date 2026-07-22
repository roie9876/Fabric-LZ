# End-to-End Deployment Guide: Platform, Fabric, and Foundry

This is the authoritative operator runbook for deploying the repository in a
customer environment without an AI assistant. It provides one ordered lifecycle
for **Layer 1 (platform)**, **Layer 2 (Fabric)**, and **Layer 3 (Foundry)**.
Follow it from top to bottom and stop at any release gate whose Terraform is not
implemented. Do not skip a **STOP** gate or reuse a saved plan after changing
permissions, code, or variables.

The guide embeds every portal screenshot already captured during the reference
deployment. Screenshots show the navigation and expected state; customer names,
subscriptions, regions, CIDRs, workspace IDs, and capacity IDs will differ.

For Layer 1 as-built evidence, see
[platform/DEPLOYMENT.md](platform/DEPLOYMENT.md). For the Fabric architecture,
see
[workloads/fabric/README.md](workloads/fabric/README.md). For the completed
Fabric reference deployment history, see
[workloads/fabric/REFERENCE-LAB.md](workloads/fabric/REFERENCE-LAB.md). For the
Foundry target architecture and current release boundary, see
[docs/03-foundry-workload.md](docs/03-foundry-workload.md).

## What this guide builds

The repository targets three cumulative layers:

| Layer | Outcome | Current release status |
|---|---|---|
| **1 — Platform** | Governance, private state, hub/firewall, DNS Resolver, private Azure Monitor/AMPLS | **Core implemented and reference-deployed; Stages 30/50 remain stubs** |
| **2 — Fabric** | Private Workspace A, public Workspace B, OPDG ingestion, semantic model/report | **Implemented and reference-deployed** |
| **3 — Foundry** | Private Foundry/Agent Service, AI Search, Storage, Cosmos DB, Application Insights through AMPLS, APIM publication | **Foundry foundation and private APIM implemented and reference-deployed; Hosted Agent/API publication pending** |

The shared network target is shown below. Layer 2 then adds a private Workspace
A that ingests on-premises SQL into OneLake and a public Workspace B that serves
the semantic model/report through an approved data gateway path.

![Landing-zone layers — hub, spokes, private monitoring, and forced egress](docs/images/02-hub-spoke.png)

![Target architecture — Microsoft Fabric workspace-level Private Link](docs/images/05-fabric-private-link.png)

Layer 3 extends the Foundry spoke shown in the landing-zone diagram. Its section
provides executable Terraform for the private Foundry foundation and APIM. The
remaining release boundary is the Hosted Agent and its APIM APIs/policies.

## Contents

- [Layer status and release boundary](#scope-and-release-boundary)
- [Required operator inputs](#required-operator-inputs)
- [Day-0 readiness gate](#day-0-readiness-gate)
- [Reference lab checkpoint](#reference-lab-checkpoint-do-not-copy-to-a-customer)
- [Execution model](#execution-model)
- [Layer 1 — Platform foundation](#layer-1--platform-foundation)
  - [1. Prepare the operator workstation](#1-prepare-the-operator-workstation)
  - [2. Establish state and Layer 1](#2-establish-private-terraform-state-and-deploy-layer-1)
  - [3. Validate the network handoff](#3-validate-the-customer-network-handoff)
- [Layer 2 — Fabric private workspace](#layer-2--fabric-private-workspace)
  - [4. Complete Fabric tenant prerequisites](#4-complete-fabric-tenant-prerequisites)
  - [5. Deploy Fabric Phase A](#5-terraform-phase-a-fabric-foundation)
  - [6. Create both workspaces](#6-create-both-fabric-workspaces)
  - [7. Grant runner workspace access](#7-grant-the-runner-fabric-workspace-lifecycle-access)
  - [8. Deploy workspace Private Link](#8-terraform-phase-b-workspace-private-link)
  - [9. Prepare SQL and OPDG](#9-prepare-the-customer-sql-server-and-opdg-hosts)
  - [10. Install and register OPDG](#10-phase-5-install-and-register-opdg)
  - [11. Create the lakehouse and ingest SQL](#11-phase-6-create-the-private-lakehouse-and-ingest-sql)
  - [12. Build the semantic model and report](#12-phase-7-build-the-public-semantic-model-and-report)
  - [13. Run pre-lockdown validation](#13-phase-8-final-pre-lockdown-validation)
  - [14. Restrict Workspace A](#14-phase-9-restrict-workspace-a-last)
  - [15. Pause nonproduction resources](#15-pause-nonproduction-resources-when-idle)
- [Layer 3 — Foundry workload](#layer-3--foundry-workload)
  - [16. Validate Layer 3 prerequisites](#16-validate-layer-3-prerequisites)
  - [17. Deploy private Foundry foundation](#17-deploy-private-foundry-foundation)
  - [18. Deploy private APIM AI Gateway](#18-deploy-private-apim-ai-gateway)
  - [19. Deploy the Foundry Hosted Agent](#19-deploy-the-foundry-hosted-agent)
  - [20. Run final Layer 3 validation](#20-run-final-layer-3-validation)
- [Evidence acceptance criteria](#evidence-acceptance-criteria)
- [Rollback order](#rollback-order)
- [Troubleshooting matrix](#troubleshooting-matrix)
- [Firewall rule reference (OPDG + Fabric)](#firewall-rule-reference-opdg--fabric)
- [Appendix A: Cross-workspace refresh into a private Workspace A](#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a)

## Scope and release boundary

This repository currently provides:

- Implemented Layer 1 roots: state storage, management-group hierarchy, hub
  VNet, Azure Firewall, Private DNS Resolver, private Log Analytics workspace,
  AMPLS, Azure Monitor private endpoint, and private DNS integration.
- Fabric Phase A: F capacity, Fabric spoke, UDR, hub peerings, diagnostics, and
  the workspace-level Private Link DNS zone.
- Fabric Phase B: the hidden workspace Private Link service, private endpoint,
  and DNS zone group.
- Optional **lab-only** SQL Server and OPDG Windows VMs in an existing simulated
  on-premises VNet.
- Layer 3 private Foundry foundation and APIM infrastructure. The Hosted Agent
  and its APIM APIs/policies remain behind their deployment acceptance gate.

This repository does **not** deploy the following customer production
dependencies. Their owners must complete and sign them off before the matching
STOP gate:

| Dependency | Customer owner | Required outcome |
|---|---|---|
| Azure subscriptions and management-group placement | Cloud platform | Target subscriptions exist; deployment identity has approved roles |
| Private Terraform runner | Cloud platform | Runner can reach Azure Resource Manager, Git, and the private state endpoint |
| Private backend endpoint and DNS path | Cloud/network | State storage resolves privately and TCP 443 succeeds from the runner |
| On-prem to hub connectivity | Network | On-prem is peered to the hub; on-prem routes the Fabric spoke and internet to the hub firewall (transit) |
| Azure Firewall/SWG rules | Network/security | Terraform, Fabric, OneLake, Entra, Azure Relay, and gateway endpoints are allowed |
| Production SQL Server | Database | Supported SQL instance, database, least-privilege login, backup, TLS, and operations ownership |
| Production OPDG hosts | Data platform | Windows Server 2019+, 8 cores/8 GB+ recommended, SSD, latest supported gateway, HA design |
| Entra Conditional Access | Identity/security | Workspace B public access is protected by an approved CA policy |
| Stages `30-egress` and `50-security` | Cloud/security | Separate production implementation; current repository roots are design stubs |

**Production release gate:** do not call this a production landing-zone
deployment until the missing customer-owned controls above are implemented and
approved. The reference lab uses one subscription, a peered on-prem simulation,
empty Firewall rule collections, and single OPDG/SQL hosts. Those are not a
production baseline.

### Supported subscription topology in this release

The current `workloads/fabric` root configures one AzureRM provider using
`subscription_id_workloads`. It also looks up the hub VNet/Firewall and central
Log Analytics workspace through that same provider. Therefore:

- **Supported and validated now:** management, connectivity, monitoring, Fabric
  workload, and state resources in one Azure subscription, with tenant-scoped
  management groups.
- **Not executable from this commit:** a true multi-subscription enterprise
  topology where hub, monitoring, and Fabric live in different subscriptions.

For multi-subscription production, stop before deployment and implement/test
aliased AzureRM providers for connectivity, monitoring, and workloads; bind each
data/resource block to its owner; add cross-subscription RBAC; then update this
guide and capture a reviewed Terraform plan. Setting different subscription IDs
in the tfvars file alone does not provide cross-subscription behavior.

## Legend

| Label | Run from | Meaning |
|---|---|---|
| **LAPTOP** | Local terminal | Azure CLI control-plane command |
| **RUNNER** | Private runner VM | Terraform command with managed identity |
| **PORTAL** | Azure, Entra, or Fabric portal | Manual operator action; capture evidence |
| **API** | Laptop or runner | Fabric/Azure API action; record request result |
| **CHECK** | Named host | Read-only validation |
| **STOP** | Operator decision | Do not continue until the stated evidence passes |

## Execution modes: Terraform vs. manual

This deployment is **mixed-mode**: some steps run **Terraform** (infrastructure
as code, from the private runner) and some are **manual** actions in a portal
(Azure, Microsoft Entra, or Microsoft Fabric) or on the on-premises hosts. Read
the mode badge at the start of every step before you begin.

- 🟦 **TERRAFORM** — run the documented `terraform` commands from the **RUNNER**.
  Do **not** create these resources by hand in the portal.
- 🟨 **MANUAL** — perform the steps yourself in a **PORTAL** / **API** / on a host
  (**LAPTOP**, **RUNNER**, SQL/OPDG VM). Terraform does not do these.
- ⬜ **PREP / VALIDATE** — one-time workstation prep or read-only checks
  (**LAPTOP** / **CHECK**); no resources are created.

### Mode at a glance

| Layer | # | Step | Mode / status |
|---|---:|---|---|
| 1 | 1 | Prepare the operator workstation | ⬜ PREP (LAPTOP) |
| 1 | 2 | Establish private state + deploy Layer 1 | 🟦 TERRAFORM (RUNNER) |
| 1 | 3 | Validate the customer network handoff | ⬜ VALIDATE (CHECK) |
| 2 | 4 | Complete Fabric tenant prerequisites | 🟨 MANUAL (PORTAL) |
| 2 | 5 | Terraform Phase A: Fabric foundation | 🟦 TERRAFORM (RUNNER) |
| 2 | 6 | Create both Fabric workspaces | 🟨 MANUAL (PORTAL) |
| 2 | 7 | Grant the runner workspace access | 🟨 MANUAL (PORTAL/API) |
| 2 | 8 | Terraform Phase B: workspace Private Link | 🟦 TERRAFORM (RUNNER) |
| 2 | 9 | Prepare the SQL Server and OPDG hosts | 🟦 TERRAFORM (RUNNER)* |
| 2 | 10 | Phase 5: install and register OPDG | 🟨 MANUAL (OPDG host) |
| 2 | 11 | Phase 6: private lakehouse + ingest SQL | 🟨 MANUAL (PORTAL) |
| 2 | 12 | Phase 7: semantic model + report | 🟨 MANUAL (PORTAL) |
| 2 | 13 | Phase 8: pre-lockdown validation | ⬜ VALIDATE (CHECK) |
| 2 | 14 | Phase 9: restrict Workspace A | 🟨 MANUAL (PORTAL) |
| 2 | 15 | Pause nonproduction resources | 🟨 MANUAL (PORTAL) |
| 3 | 16 | Validate Foundry region, quota, providers, runner, and CIDRs | ⬜ VALIDATE (CHECK) |
| 3 | 17 | Deploy Template 19 private Foundry foundation | 🟦 TERRAFORM (RUNNER) |
| 3 | 18 | Deploy APIM Standard v2 private AI Gateway | 🟦 TERRAFORM (RUNNER) |
| 3 | 19 | Deploy Responses Hosted Agent with private Search | 🟦 AZD (PRIVATE CLIENT) |
| 3 | 20 | Validate private agent, gateway, telemetry, DNS, and drift | ⬜ VALIDATE (CHECK) |

\* Step 9 uses Terraform only for the **lab** SQL/OPDG hosts. In a customer
environment these are customer-owned production hosts (manual).

```mermaid
flowchart TD
    S1["1. Prepare workstation<br/>⬜ PREP"] --> S2["2. Private state + Layer 1<br/>🟦 TERRAFORM"]
    S2 --> S3["3. Validate network handoff<br/>⬜ VALIDATE"]
    S3 --> S4["4. Fabric tenant prerequisites<br/>🟨 MANUAL portal"]
    S4 --> S5["5. Phase A: Fabric foundation<br/>🟦 TERRAFORM"]
    S5 --> S6["6. Create both workspaces<br/>🟨 MANUAL portal"]
    S6 --> S7["7. Grant runner access<br/>🟨 MANUAL portal/API"]
    S7 --> S8["8. Phase B: workspace Private Link<br/>🟦 TERRAFORM"]
    S8 --> S9["9. Prepare SQL + OPDG hosts<br/>🟦 TERRAFORM lab / 🟨 MANUAL cust."]
    S9 --> S10["10. Phase 5: install + register OPDG<br/>🟨 MANUAL host"]
    S10 --> S11["11-15. Complete Fabric lifecycle<br/>🟨 MANUAL + VALIDATE"]
    S11 --> S16["16. Validate Layer 3 prerequisites<br/>⬜ VALIDATE"]
    S16 --> S17["17. Private Foundry foundation<br/>🟦 TERRAFORM"]
    S17 --> S18["18. Private APIM AI Gateway<br/>🟦 TERRAFORM"]
    S18 --> S19["19. Foundry Hosted Agent<br/>🟦 AZD"]
    S19 --> S20["20. Layer 3 acceptance<br/>⬜ VALIDATE"]

    classDef tf fill:#e3f0ff,stroke:#2b6cb0,color:#1a365d;
    classDef manual fill:#fff7e0,stroke:#b7791f,color:#744210;
    classDef prep fill:#f0f0f0,stroke:#888,color:#333;
    classDef blocked fill:#fde8e8,stroke:#c53030,color:#742a2a;
    class S2,S5,S8 tf;
    class S4,S6,S7,S10,S11 manual;
    class S1,S3,S9 prep;
    class S17,S18 tf;
    class S16,S20 prep;
    class S19 manual;
```

### About the reference screenshots in this guide

> 📸 **Reference-only screenshots.** For each **🟦 TERRAFORM** step, this guide
> embeds Azure portal screenshots under a *"Expected Terraform result"* heading.
> **These are for verification only** — they show what the portal should look
> like *after* the `terraform apply` succeeds, so you can confirm the result in a
> customer environment. **Do not recreate these resources by hand**; Terraform
> already builds them. Screenshots are from the reference lab
> (`azr-sbx-lab-0001`, Israel Central); your names, IDs, and regions will differ.

## Required operator inputs

Create an approved deployment worksheet before running commands. Never put
secret values in this document or Git.

| Input | Example variable | Record before starting |
|---|---|---|
| Tenant ID | `TENANT_ID` | `<customer-tenant-guid>` |
| Management subscription | `subscription_id_management` | `<guid>` |
| Connectivity subscription | `subscription_id_connectivity` | `<guid>` |
| Workloads subscription | `subscription_id_workloads` | `<guid>` |
| Monitoring subscription | `subscription_id_monitor` | `<guid>` |
| Region | `location` | Customer-approved Fabric/Azure region |
| Naming tokens | `env`, `org`, `subcode_*` | Approved naming values |
| Hub/Fabric/on-prem CIDRs | `hub_vnet_cidr`, `fabric_spoke_cidr` | Non-overlapping ranges |
| Fabric administrator UPN | `fabric_admin_upn` | Named operator or approved group member |
| Private runner | `RUNNER_RG`, `RUNNER_VM` | Existing private execution host |
| Private variables file | `TFVARS_FILE` | `_private/customer.private.tfvars` |
| Backend file | `BACKEND_FILE` | `_private/backend.hcl` |
| Evidence folder | `EVIDENCE_DIR` | `workloads/fabric/images/` or customer evidence system |

Subcodes are cross-root lookup keys, not cosmetic labels.
`subcode_connectivity` in every workload must match the deployed hub, and
`subcode_monitor` must match the monitoring workspace. A mismatch makes data
sources look for resources that do not exist.

For the currently supported path, record the same subscription GUID for all
subscription inputs. Different GUIDs require the provider refactor above.

## Day-0 readiness gate

The customer must complete this checklist before Terraform:

- [ ] Address spaces do not overlap with on-premises, hub, peer VNets, or other
  cloud networks.
- [ ] Fabric F SKU is available in the selected region and the subscription has
  sufficient quota.
- [ ] `Microsoft.Fabric`, `Microsoft.Network`, `Microsoft.Compute`,
  `Microsoft.Storage`, `Microsoft.OperationalInsights`, and
  `Microsoft.Insights` providers are registered in the relevant subscriptions.
- [ ] The deployment identity can create resources in each target subscription
  and has management-group rights if Stage 10 will be used.
- [ ] The runner identity has **Storage Blob Data Contributor** on the state
  container or storage account. Azure Contributor alone does not grant state
  data-plane access.
- [ ] The private runner resolves the state account to a private IP and reaches
  it on TCP 443.
- [ ] On-prem to hub VNet peering, DNS forwarding, Firewall/SWG rules, and return
  routes are approved and tested.
- [ ] A Fabric Administrator can open the Fabric Admin portal and can become
  Workspace A Admin.
- [ ] Change records, rollback owners, evidence location, maintenance window,
  and cost owner are assigned.

**STOP:** if any box is unchecked, hand the action to the named customer owner.
The Terraform in this repository cannot repair missing enterprise prerequisites.

## Reference lab checkpoint (do not copy to a customer)

As of **2026-07-20**:

- Platform foundation, Fabric Phase A, and Fabric Phase B are deployed and
  converged.
- SQL and OPDG lab VMs are deployed; the gateway is registered and Online.
- Private lakehouse ingestion and the public semantic model/report are
  validated.
- Workspace A denies public inbound access and remains reachable through its
  workspace-level private endpoint.
- Workspace B refreshes through the OPDG using the workspace-private SQL
  analytics endpoint; post-lockdown report validation completed.
- The reference-lab Conditional Access evidence is still pending. Treat the
  production release gate as open until an approved policy is applied and
  tested.

Reference records:

- [Platform Layer 1 as-built evidence](platform/DEPLOYMENT.md)
- [Fabric reference-lab history and screenshots](workloads/fabric/REFERENCE-LAB.md)

## Execution model

Terraform state is private. Run Terraform from the customer-provided private
runner, not an off-network laptop. The reference lab uses Azure VM Run Command;
customers can use their approved private CI agent, privileged access
workstation, or management host instead.

The three Layer 2 Terraform roots use independent state keys:

| Terraform root | State key |
|---|---|
| `workloads/fabric` | `workloads-fabric.tfstate` |
| `workloads/fabric-private-link` | `workloads-fabric-private-link.tfstate` |
| `workloads/onprem-lab` | `workloads-onprem-lab.tfstate` (lab only) |

Never combine these states. Never put passwords, access tokens, recovery keys,
private tfvars, Terraform plans, or state files in Git or screenshots.

### How to execute a RUNNER block

Start the runner, verify `/home/azureuser/lz` is on the approved commit, then use
this reference pattern from the laptop if Azure VM Run Command is the approved
access method. Replace every placeholder. Keep credentials out of the command.

```bash
SUBSCRIPTION_ID=<runner-subscription-id>
TENANT_ID=<tenant-id>
RUNNER_RG=<runner-resource-group>
RUNNER_VM=<runner-vm-name>
TERRAFORM_ROOT=workloads/fabric
TFVARS_FILE=../../_private/customer.private.tfvars
BACKEND_FILE=../../_private/backend.hcl

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
git rev-parse --short HEAD
terraform init -reconfigure -backend-config=$BACKEND_FILE
terraform validate
terraform plan -var-file=$TFVARS_FILE -out=deployment.tfplan
terraform show -no-color deployment.tfplan"
```

Review the plan before running a second invocation that applies the saved plan.
Do not combine plan and apply when a stop gate requires human approval.

When running the later **RUNNER** blocks in an interactive shell instead of the
wrapper, initialize the session first:

```bash
export HOME=/home/azureuser
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID=<subscription-used-by-this-root>
export ARM_TENANT_ID=<tenant-guid>
export TFVARS_FILE=../../_private/customer.private.tfvars
export BACKEND_FILE=../../_private/backend.hcl
```

Change `ARM_SUBSCRIPTION_ID` for each root's owning subscription. Confirm the
managed identity has the required management- and data-plane roles before plan.

Terraform exit codes:

- `0`: command succeeded; for `plan -detailed-exitcode`, no changes remain.
- `1`: error; stop and resolve it.
- `2`: `plan -detailed-exitcode` succeeded and changes are pending.

After every apply, rerun the same plan with `-detailed-exitcode`. Continue only
when it returns `0`. If code, variables, identity, or permissions change after a
plan is saved, delete that plan and create a new one.

## Layer 1 — Platform foundation

### 1. Prepare the operator workstation

> **Mode: ⬜ PREP (LAPTOP)** — one-time workstation setup; no Azure resources created.

**LAPTOP**

```bash
export TENANT_ID=<customer-tenant-guid>
export MANAGEMENT_SUBSCRIPTION_ID=<management-subscription-guid>
export CONNECTIVITY_SUBSCRIPTION_ID=<connectivity-subscription-guid>
export WORKLOADS_SUBSCRIPTION_ID=<workloads-subscription-guid>
export MONITOR_SUBSCRIPTION_ID=<monitor-subscription-guid>
export LOCATION=<approved-azure-region>

az login --tenant "$TENANT_ID"
az account show --query '{tenant:tenantId,subscription:id,user:user.name}' -o table
terraform version  # must be >= 1.6
az version
jq --version
curl --version
bash scripts/check-sensitive.sh
```

Create the private overlay from the examples and fill in environment-specific
values. `_private/` is ignored by Git.

```bash
cp _private/denylist.txt.example _private/denylist.txt
cp examples/enterprise/enterprise.tfvars.example \
  _private/customer.private.tfvars
```

Add every variable required by the selected roots. At minimum, the Fabric path
needs subscription IDs, tenant ID, naming tokens, region, hub/spoke CIDRs,
Fabric capacity SKU, Fabric administrator UPN, and later Workspace A ID. Compare
the private file with each selected root's `variables.tf`.

Minimum cross-root template; replace every placeholder and use customer-approved
non-overlapping CIDRs:

```hcl
tenant_id                    = "<tenant-guid>"
subscription_id_management   = "<management-subscription-guid>"
subscription_id_connectivity = "<connectivity-subscription-guid>"
subscription_id_workloads    = "<workloads-subscription-guid>"
subscription_id_monitor      = "<monitor-subscription-guid>"

env      = "prd"
org      = "<approved-org-token>"
location = "<approved-region>"

subcode_management   = "<management-code>"
subcode_connectivity = "<connectivity-code>"
subcode_monitor      = "<monitor-code>"
subcode_fabric       = "<fabric-code>"

hub_vnet_cidr = "<hub-cidr>"
subnet_prefixes = {
  firewall                 = "<azure-firewall-subnet-cidr>"
  dns_inbound              = "<dns-inbound-subnet-cidr>"
  dns_outbound             = "<dns-outbound-subnet-cidr>"
  egress_swg               = "<egress-swg-subnet-cidr>"
  monitor_private_endpoint = "<azure-monitor-private-endpoint-subnet-cidr>"
}
enable_ddos = true

fabric_spoke_cidr       = "<fabric-spoke-cidr>"
fabric_pe_subnet_prefix = "<fabric-private-endpoint-subnet-cidr>"
fabric_capacity_sku     = "F2"
fabric_admin_upn        = "<fabric-administrator-upn>"

# Add after Workspace A is created:
# fabric_private_workspace_id = "<workspace-a-guid>"
```

Verify the approved tenant and all target subscriptions before continuing. Then
register the resource providers listed below. Re-running registration is safe.

```bash
for namespace in Microsoft.Resources Microsoft.Storage; do
  az provider register --subscription "$MANAGEMENT_SUBSCRIPTION_ID" \
    --namespace "$namespace" --wait
done

for namespace in Microsoft.Network Microsoft.Compute Microsoft.Storage; do
  az provider register --subscription "$CONNECTIVITY_SUBSCRIPTION_ID" \
    --namespace "$namespace" --wait
done

for namespace in Microsoft.Fabric Microsoft.Network Microsoft.Insights; do
  az provider register --subscription "$WORKLOADS_SUBSCRIPTION_ID" \
    --namespace "$namespace" --wait
done

for namespace in Microsoft.OperationalInsights Microsoft.Insights; do
  az provider register --subscription "$MONITOR_SUBSCRIPTION_ID" \
    --namespace "$namespace" --wait
done
```

**Evidence:** save the approved input worksheet, account context, RBAC approval,
provider registration, F SKU quota/region approval, and CIDR review in the
customer change record. Do not commit customer identifiers to this repository.

**STOP:** tenant and subscription IDs must match the approved change record.

The current lab already has its private overlay and backend configuration. Do
not overwrite them when resuming.

### 2. Establish private Terraform state and deploy Layer 1

> **Mode: 🟦 TERRAFORM (RUNNER)** — infrastructure as code. Do not build these
> resources by hand; see *Expected Terraform result* screenshots at the end of
> this step to verify.

#### 2.1 Customer-provided private backend

This is a mandatory Day-0 handoff. `platform/00-bootstrap` creates a
private-only storage account and container, but it does **not** create the
private endpoint, DNS record, runner, or RBAC path needed to reach that account.
Do not run it from an off-network laptop and expect a complete backend.

The platform team must provide or precreate:

1. State resource group, storage account, and `tfstate` container.
2. Shared-key access disabled and public network access disabled.
3. Blob private endpoint reachable from the runner.
4. `privatelink.blob.core.windows.net` DNS record and forwarding path.
5. **Storage Blob Data Contributor** for the runner identity.
6. Blob versioning, retention, logging, and customer backup controls.

Create `_private/backend.hcl` only on the runner or through the approved secure
configuration process:

```hcl
resource_group_name  = "<state-resource-group>"
storage_account_name = "<state-storage-account>"
container_name       = "tfstate"
use_azuread_auth     = true
```

**RUNNER CHECK**

```bash
STATE_ACCOUNT=<state-storage-account>
getent ahostsv4 "$STATE_ACCOUNT.blob.core.windows.net"
curl -I --connect-timeout 10 \
  "https://$STATE_ACCOUNT.blob.core.windows.net"

cd /home/azureuser/lz/platform/00-bootstrap
export ARM_SUBSCRIPTION_ID=<management-subscription-guid>
export ARM_TENANT_ID=<tenant-guid>
export ARM_USE_MSI=true
export BACKEND_FILE=../../_private/backend.hcl
terraform init -reconfigure -backend-config="$BACKEND_FILE"
```

Expected: private IP resolution and an HTTP response over TCP 443. An HTTP
`403` can prove network reachability, but Terraform still needs data-plane RBAC.
Terraform must report that the AzureRM backend initialized successfully.

If the customer precreated the three Stage 00 resources and wants Terraform to
own them, initialize the `00-bootstrap` backend and import the resource group,
storage account, and container before planning. Do not import the private
endpoint into this root; it is not declared there.

**STOP:** `terraform init` from the runner must access the backend without a
storage key before any other root is deployed.

#### 2.2 Implemented Layer 1 roots

Skip this section when resuming the current lab. The implemented platform roots
were deployed in this order:

1. `platform/00-bootstrap`
2. `platform/10-management-groups`
3. `platform/20-connectivity-hub`
4. `platform/40-monitoring`

`platform/30-egress` and `platform/50-security` are design stubs. Do not mark
egress or security complete because Terraform returns no changes for those
roots. Customer Firewall/SWG rules, Defender, policy, and CNAPP
controls require separate approved implementations.

Set the runner's subscription context for each implemented root:

| Root | `ARM_SUBSCRIPTION_ID` |
|---|---|
| `platform/00-bootstrap` | Management subscription |
| `platform/10-management-groups` | Management subscription; operations are tenant-scoped |
| `platform/20-connectivity-hub` | Connectivity subscription |
| `platform/40-monitoring` | Monitoring subscription |
| `workloads/fabric` | Workloads subscription; current release requires the supported single-subscription topology |
| `workloads/fabric-private-link` | Workloads subscription |
| `workloads/onprem-lab` | Workloads subscription; optional lab only |

For each implemented root, run **RUNNER**:

```bash
cd /home/azureuser/lz/<terraform-root>
terraform init -reconfigure -backend-config="$BACKEND_FILE"
terraform validate
rm -f stage.tfplan
terraform plan -var-file="$TFVARS_FILE" -out=stage.tfplan
terraform show -no-color stage.tfplan
# Human review and change approval happen here.
terraform apply stage.tfplan
terraform plan -detailed-exitcode -var-file="$TFVARS_FILE"
```

Expected final detailed exit code: `0` (`No changes`). Review
[platform/DEPLOYMENT.md](platform/DEPLOYMENT.md) for Layer 1 screenshots and the
as-built inventory.

After Stage 20, the production network team must establish the customer hybrid
path and approved Firewall/SWG rules. In the optional sandbox path,
`workloads/onprem-lab` owns the direct on-prem-to-hub peerings and the workload
UDR that sends the Fabric prefix and default route through the hub firewall.
For a greenfield deployment, first apply Stage 20 with firewall diagnostics
disabled, apply Stage 40, then re-apply Stage 20 with diagnostics enabled. After
Stage 40, verify the private Log Analytics workspace, AMPLS scoped-resource
association, approved hub private endpoint, and all five Azure Monitor private
DNS zones. DCRs, alerting, and workbooks remain extension points.

**STOP:** the hub VNet, Azure Firewall, DNS Resolver, Log Analytics workspace,
AMPLS private endpoint and DNS, private state path, and customer hybrid path
must all be healthy before Layer 2.

#### Expected Terraform result (reference screenshots)

> 📸 **Reference only — do not perform manually.** These show the expected Azure
> portal state **after** `terraform apply` succeeds for Layer 1. Use them to
> verify your customer deployment. Names/IDs/regions will differ from the lab.

**Management groups** — the governance hierarchy (CAF-style `mgmt / workloads /
monitor / sandbox` in production; the reference tenant shows its own tree).

![Layer 1 — management groups](docs/deployment-reference/tf-layer1-01-management-groups.png)

**Resource groups** — the Layer 1 resource groups, all in the target region.

![Layer 1 — resource groups](docs/deployment-reference/tf-layer1-02-resource-groups.png)

**Private Terraform state storage** — public network access **Disabled**, shared
key access **Disabled**, a private endpoint connection, and versioning **Enabled**.

![Layer 1 — tfstate storage account](docs/deployment-reference/tf-layer1-03-tfstate-storage.png)

**Hub VNet subnets** — Firewall, DNS inbound/outbound, egress, and the dedicated
Azure Monitor private-endpoint subnet.

![Layer 1 — hub VNet subnets](docs/deployment-reference/tf-layer1-04-hub-vnet-subnets.png)

**Azure Firewall** — Standard SKU, private IP, attached Firewall Policy.

![Layer 1 — Azure Firewall](docs/deployment-reference/tf-layer1-05-azure-firewall.png)

**Firewall Policy** — Standard tier, attached to the hub firewall.

![Layer 1 — Firewall Policy](docs/deployment-reference/tf-layer1-06-firewall-policy.png)

**Private DNS Resolver** — one inbound and one outbound endpoint, Connected.

![Layer 1 — Private DNS Resolver](docs/deployment-reference/tf-layer1-07-dns-resolver.png)

**Central Log Analytics workspace** — Active, pay-as-you-go.

![Layer 1 — Log Analytics](docs/deployment-reference/tf-layer1-08-log-analytics.png)

**Log Analytics network isolation** — public ingestion and query are both
**Restricted** (public network access disabled); the workspace is reachable only
through the Azure Monitor private endpoint.

![Layer 1 — Log Analytics network isolation](docs/deployment-reference/tf-layer1-09-law-network-isolation.png)

**Azure Monitor Private Link Scope** — Succeeded with one private endpoint and
the central Log Analytics workspace as a scoped resource.

![Layer 1 — AMPLS overview](docs/deployment-reference/tf-layer1-10-ampls-overview.png)

![Layer 1 — AMPLS scoped resources](docs/deployment-reference/tf-layer1-11-ampls-scoped-resources.png)

**Private-only access modes** — ingestion and query both set to **Private Only**.

![Layer 1 — AMPLS access modes](docs/deployment-reference/tf-layer1-12-ampls-access-modes.png)

**AMPLS private endpoint** — deployed in the hub `AzureMonitorPrivateEndpointSubnet`,
connection state **Approved**, targeting the `azuremonitor` sub-resource.

![Layer 1 — AMPLS private endpoint](docs/deployment-reference/tf-layer1-13-ampls-private-endpoint.png)

**AMPLS private DNS integration** — the endpoint registers the Azure Monitor
FQDNs to private IPs across all five required zones (`privatelink.monitor.azure.com`,
`privatelink.oms.opinsights.azure.com`, `privatelink.ods.opinsights.azure.com`,
`privatelink.agentsvc.azure-automation.net`, and `privatelink.blob.core.windows.net`).

![Layer 1 — AMPLS private DNS zones](docs/deployment-reference/tf-layer1-14-ampls-dns-zones.png)

### 3. Validate the customer network handoff

> **Mode: ⬜ VALIDATE (CHECK)** — read-only connectivity checks; no resources created.

The network team must provide the hub VNet/resource group, Azure Firewall
private IP, DNS Resolver inbound IP, on-premises SQL/OPDG subnets, hybrid route
evidence, and Firewall/SWG change IDs. The names must match the `env`, `org`, and
`subcode_connectivity` values used by the workload Terraform data sources.

**CHECK from the runner and planned OPDG network**

```powershell
Test-NetConnection <private-state-fqdn> -Port 443
Test-NetConnection login.microsoftonline.com -Port 443
Test-NetConnection api.fabric.microsoft.com -Port 443
```

Required OPDG public-cloud outbound rules include:

- TCP 443 to `*.download.microsoft.com`, `*.powerbi.com`,
  `*.analysis.windows.net`, Entra sign-in endpoints,
  `gatewayadminportal.azure.com`, `*.dc.services.visualstudio.com`, and
  `ecs.office.com`.
- TCP 443 and, when HTTPS-only mode is not enforced, TCP 5671-5672 and
  9350-9354 to `*.servicebus.windows.net`.
- TCP 443 to Fabric workload endpoints including
  `*.dfs.fabric.microsoft.com` and `*.frontend.clouddatahub.net`.
- When warehouse staging is used, TCP 1433 to both
  `*.datawarehouse.pbidedicated.windows.net` and
  `*.datawarehouse.fabric.microsoft.com`.
- No inbound internet ports are required by OPDG.

Prefer FQDN rules or documented Microsoft service tags where supported. Azure
Relay has no dedicated service tag; the gateway app's network ports test is the
final authority for its current region endpoints.

The complete, tag-free rule set (network, application, TDS, management-plane, and
default-deny) is in the [Firewall rule reference (OPDG + Fabric)](#firewall-rule-reference-opdg--fabric)
appendix.

**Evidence:** BGP/route tables, DNS forwarding, Firewall/SWG change, and TCP
tests.

**STOP:** do not deploy the Fabric spoke until the customer network owner signs
off routing, DNS, and egress.

## Layer 2 — Fabric private workspace

### 4. Complete Fabric tenant prerequisites

> **Mode: 🟨 MANUAL (PORTAL)** — perform these steps yourself in Microsoft Entra
> and the Fabric admin portal. Terraform does not do these.

Skip this section when resuming the current lab; it is complete.

**PORTAL: Microsoft Entra admin center**

1. Open **Identity governance** > **Privileged Identity Management** >
   **Microsoft Entra roles**.
2. Assign or activate **Fabric Administrator** for the operator.
3. Complete the wizard. Allow up to 15-30 minutes for propagation, then sign out
  of Fabric completely and sign in again in a new browser session.
4. Verify the operator can open the Fabric **Admin portal**.

Reference screenshot: Fabric Administrator role assignment.

![Fabric Administrator role assignment](workloads/fabric/images/fabric%20admin%20role%20in%20entra.jpeg)

Completed role evidence — the operator has a direct, active, permanent
**Fabric Administrator** assignment at tenant scope:

![Fabric Administrator role effective](workloads/fabric/images/02-fabric-admin-role-effective.jpeg)

**PORTAL: Microsoft Fabric**

1. Open **Settings** > **Admin portal**.

![Open the Fabric Admin portal](workloads/fabric/images/01-open-admin-portal.png.jpeg)

2. Select **Tenant settings**.
3. Under **Advanced networking**, open **Configure workspace-level inbound
   network rules**.
4. Enable it for the customer-approved security group or the entire
  organization.

Reference screenshot: enabled selection before Apply. The **Unapplied changes**
banner means the action is not complete.

![Enable workspace-level inbound network rules](workloads/fabric/images/workspace%20level%20rule.jpeg)

5. Select **Apply**, wait for propagation, refresh the page, and verify the
  setting persists with no unapplied changes.

Reference screenshot: final applied state.

![Workspace-level inbound rule applied](workloads/fabric/images/workspace-level-rule-applied.jpeg)

**LAPTOP**

```bash
az provider register \
  --namespace Microsoft.Fabric \
  --subscription "$WORKLOADS_SUBSCRIPTION_ID" \
  --wait

az provider show \
  --namespace Microsoft.Fabric \
  --subscription "$WORKLOADS_SUBSCRIPTION_ID" \
  --query registrationState -o tsv
```

**Customer evidence:** capture the customer equivalent of all four screens. Do
not reuse these reference screenshots as proof of the customer change.

**STOP:** Admin portal access must work, the setting must remain enabled after
refresh, and the provider must report `Registered`.

### 5. Terraform Phase A: Fabric foundation

> **Mode: 🟦 TERRAFORM (RUNNER)** — infrastructure as code. Do not build these
> resources by hand; see *Expected Terraform result* screenshots at the end of
> this step to verify.

Skip this section when resuming the current lab; it is complete and had no
drift before shutdown.

Phase A creates the F2 capacity, Fabric spoke, private-endpoint subnet, route
table, hub peerings, diagnostics, and `privatelink.fabric.microsoft.com` zone.

**RUNNER**

```bash
cd /home/azureuser/lz/workloads/fabric
terraform init -reconfigure -backend-config="$BACKEND_FILE"
terraform validate
rm -f phase-a.tfplan
terraform plan \
  -var-file="$TFVARS_FILE" \
  -out=phase-a.tfplan
terraform show -no-color phase-a.tfplan
# Human review and approval happen here.
terraform apply phase-a.tfplan
terraform plan \
  -detailed-exitcode \
  -var-file="$TFVARS_FILE"
```

Reference deployment expectation: `13 added, 0 changed, 0 destroyed`.
Final expectation: exit code `0`, no drift.

No portal screenshot is required for this Terraform-only phase. Record the plan,
apply summary, and read-only Azure checks in the runbook.

**RUNNER CHECK**

```bash
SPOKE_VNET_ID=$(terraform output -raw fabric_spoke_vnet_id)
CAPACITY_ID=$(terraform output -raw fabric_capacity_id)
DNS_ZONE_ID=$(terraform output -raw workspace_private_dns_zone_id)

az resource show --ids "$SPOKE_VNET_ID" \
  --query '{name:name,state:properties.provisioningState,address:properties.addressSpace.addressPrefixes}' -o json
az resource show --ids "$CAPACITY_ID" \
  --query '{name:name,state:properties.state,provisioning:properties.provisioningState,sku:sku.name}' -o json
az network private-dns link vnet list \
  --resource-group "$(echo "$DNS_ZONE_ID" | cut -d/ -f5)" \
  --zone-name "$(basename "$DNS_ZONE_ID")" \
  --query '[].{name:name,state:virtualNetworkLinkState,provisioning:provisioningState}' -o table
```

In Azure, also verify:

- `pe-subnet` has the approved prefix and private endpoint policies disabled.
- `to-firewall` is `0.0.0.0/0` to the actual hub Firewall private IP.
- `fabric-spoke-to-hub` and `hub-to-fabric-spoke` are `Connected` with forwarded
  traffic allowed (firewall transit).
- DNS links for hub and Fabric spoke report completed/succeeded.
- F capacity is active and has the approved administrator.

The spoke reaches on-prem via the hub firewall (on-prem is separately peered to
the hub; VNet peering is non-transitive). No gateway transit is used.

**STOP:** all checks must pass and the post-apply plan must return `0`.

#### Expected Terraform result (reference screenshots)

> 📸 **Reference only — do not perform manually.** Expected Azure portal state
> **after** Phase A `terraform apply` succeeds. Verify against your environment.

**Fabric capacity** — Status **Active**, the approved SKU (lab uses F2).

![Phase A — Fabric capacity](docs/deployment-reference/tf-phasea-01-fabric-capacity.png)

**Fabric spoke VNet** — the `pe-subnet` with an attached NSG and route table.

![Phase A — Fabric spoke VNet](docs/deployment-reference/tf-phasea-02-spoke-vnet-subnets.png)

**Forced-tunnel route table** — a single route `0.0.0.0/0 → VirtualAppliance`
(the hub Azure Firewall private IP).

![Phase A — spoke route table](docs/deployment-reference/tf-phasea-03-route-table.png)

**Spoke ↔ hub peering** — Fully Synchronized / Connected.

![Phase A — spoke peering](docs/deployment-reference/tf-phasea-04-spoke-peerings.png)

**`privatelink.fabric.microsoft.com` DNS zone** — linked to the hub and spoke VNets.

![Phase A — Fabric private DNS zone](docs/deployment-reference/tf-phasea-05-fabric-dns-zone.png)

### 6. Create both Fabric workspaces

> **Mode: 🟨 MANUAL (PORTAL)** — create the workspaces yourself in Microsoft Fabric.

Skip this section when resuming the current lab; it is complete.

**PORTAL: Microsoft Fabric**

Create Workspace A:

1. Open **Workspaces** > **New workspace**.

![Open the New workspace form](workloads/fabric/images/03-open-new-workspace.jpeg)

2. Enter the approved private workspace name. Leave **Domain** empty unless the
  customer has an approved Fabric domain design. Keep the accountable
  administrators in the contact list.

![Enter Workspace A details](workloads/fabric/images/04-private-workspace-details.jpeg)

3. Under **Advanced**, select the F capacity created in Phase A. Confirm the
  capacity name and region; do not select Trial, Pro, or P SKU.

![Assign Workspace A to the F capacity](workloads/fabric/images/05-private-workspace-capacity-selection.jpeg)

4. Select **Apply**. Reopen **Workspace settings** > **Workspace type** (or
  **License info**) and confirm the saved name, `Fabric` type, capacity, SKU,
  and region.

![Workspace A created and assigned](workloads/fabric/images/06-private-workspace-created-and-capacity-assigned.jpeg)

5. Keep Workspace A inbound public access enabled during deployment. It is
  restricted only in Step 14 after all private and gateway tests pass.
6. Copy Workspace A's object ID from the `group=` value in the workspace URL.

Create Workspace B:

1. Create the approved public/reporting workspace name and verify the saved
  General settings.

![Workspace B general settings](workloads/fabric/images/07-public-workspace-details.jpeg)

2. Assign Workspace B to the same approved F capacity and verify the applied
  Workspace type/License info after refresh.

![Workspace B created and assigned](workloads/fabric/images/08-public-workspace-created-and-capacity-assigned.jpeg)

3. Keep Workspace B public access enabled only when the customer-approved Entra
  Conditional Access policy is active and tested.
4. Copy Workspace B's object ID from its workspace URL.

Record both workspace IDs and the capacity ID. Add only Workspace A's ID to the
private tfvars file:

```hcl
fabric_private_workspace_id = "<workspace-a-object-id>"
```

**Customer evidence:** capture the customer equivalent of all six screens and
record Workspace A ID, Workspace B ID, capacity resource ID, capacity object ID,
region, workspace administrators, and Conditional Access change/test evidence.

**STOP:** both workspaces must show the saved names and F capacity assignment
after refresh. Workspace A and B must still allow public access at this stage.

### 7. Grant the runner Fabric workspace lifecycle access

> **Mode: 🟨 MANUAL (PORTAL/API)** — assign workspace access yourself.

Skip this section when resuming the current lab; it is complete.

**API**

The runner managed identity needs both Azure Contributor permissions and Fabric
Workspace A `Admin`. Use a signed-in Fabric Administrator to add the runner's
service principal through the Fabric workspace role-assignment API. Record the
HTTP result and read the assignment back. Do not record the bearer token.

Run from the authenticated operator workstation. `RUNNER_PRINCIPAL_ID` is the
managed identity's **service principal object ID**, not its application/client
ID.

```bash
export WORKSPACE_A_ID=<private-workspace-guid>
export RUNNER_PRINCIPAL_ID=<runner-service-principal-object-guid>

az ad sp show --id "$RUNNER_PRINCIPAL_ID" \
  --query '{objectId:id,appId:appId,displayName:displayName,type:servicePrincipalType}' \
  -o json

TOKEN=$(az account get-access-token \
  --resource https://api.fabric.microsoft.com \
  --query accessToken -o tsv)

HTTP_CODE=$(curl -sS -o /tmp/fabric-role-add.json -w '%{http_code}' \
  -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  "https://api.fabric.microsoft.com/v1/workspaces/$WORKSPACE_A_ID/roleAssignments" \
  -d "{\"principal\":{\"id\":\"$RUNNER_PRINCIPAL_ID\",\"type\":\"ServicePrincipal\"},\"role\":\"Admin\"}")

unset TOKEN
echo "HTTP $HTTP_CODE"
jq . /tmp/fabric-role-add.json
test "$HTTP_CODE" = "201"
```

Read the assignment back with a new short-lived token:

```bash
TOKEN=$(az account get-access-token \
  --resource https://api.fabric.microsoft.com \
  --query accessToken -o tsv)

curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.fabric.microsoft.com/v1/workspaces/$WORKSPACE_A_ID/roleAssignments" \
  | jq --arg id "$RUNNER_PRINCIPAL_ID" \
    '[.value[] | select(.principal.id == $id) | {principal:.principal,role:.role}]'

unset TOKEN
```

Expected: POST returns HTTP `201`; read-back returns the service principal with
role `Admin`. A `403` means the signed-in operator lacks workspace/admin rights.
A Phase B `409 Workspace validation failed` usually means the ARM deployment
identity is not Workspace A Admin or the workspace ID/tenant is wrong.

Retain this assignment. Terraform needs it to update or destroy the hidden
workspace Private Link service later.

**Evidence:** save the service principal metadata, HTTP status, and redacted
read-back. Delete `/tmp/fabric-role-add.json`; never store the token.

**STOP:** read-back must show the runner as Workspace A `Admin`.

### 8. Terraform Phase B: workspace Private Link

> **Mode: 🟦 TERRAFORM (RUNNER)** — infrastructure as code. Do not build these
> resources by hand; see *Expected Terraform result* screenshots at the end of
> this step to verify.

Skip this section when resuming the current lab; it is complete and had no
drift before shutdown.

**RUNNER**

```bash
cd /home/azureuser/lz/workloads/fabric-private-link
terraform init -reconfigure -backend-config="$BACKEND_FILE"
terraform validate
rm -f phase-b.tfplan
terraform plan \
  -var-file="$TFVARS_FILE" \
  -out=phase-b.tfplan
terraform show -no-color phase-b.tfplan
# Human review and approval happen here.
terraform apply phase-b.tfplan
terraform plan \
  -detailed-exitcode \
  -var-file="$TFVARS_FILE"
```

Reference deployment expectation: `2 added, 0 changed, 0 destroyed`.
Final expectation: exit code `0`, no drift.

**RUNNER CHECK**

```bash
PE_ID=$(terraform output -raw workspace_private_endpoint_id)
PLS_ID=$(terraform output -raw workspace_private_link_service_id)
WORKSPACE_API_FQDN=$(terraform output -raw workspace_api_fqdn)
terraform output -json workspace_private_endpoint_ips | jq .

az resource show --ids "$PLS_ID" \
  --query '{name:name,state:properties.provisioningState,workspace:properties.workspaceId}' -o json
az network private-endpoint show --ids "$PE_ID" \
  --query '{name:name,state:provisioningState,connections:privateLinkServiceConnections[].privateLinkServiceConnectionState.status,nic:networkInterfaces[0].id}' \
  -o json
```

Expected: Private Link service `Succeeded`; private endpoint `Succeeded`;
connection `Approved`; five private IP addresses returned. Reserve at least ten
subnet addresses per workspace endpoint even though Fabric currently allocates
five.

**CHECK: on-prem test VM or OPDG VM**

Verify the five Workspace A FQDNs resolve to the private endpoint IPs and accept
TCP 443. The actual IPs are allocated dynamically; the reference lab values are
shown only to explain the mapping:

| Endpoint | Expected IP |
|---|---|
| Workspace API | `10.2.0.4` |
| Control | `10.2.0.5` |
| OneLake | `10.2.0.6` |
| DFS | `10.2.0.7` |
| Blob | `10.2.0.8` |

Construct the customer FQDNs from Workspace A ID: remove dashes, then use `z`
plus the first two ID characters.

```powershell
$workspaceId = "<workspace-a-guid>"
$compact = $workspaceId.Replace("-", "").ToLower()
$prefix = $compact.Substring(0, 2)
$names = @(
  "$compact.z$prefix.w.api.fabric.microsoft.com",
  "$compact.z$prefix.c.fabric.microsoft.com",
  "$compact.z$prefix.onelake.fabric.microsoft.com",
  "$compact.z$prefix.dfs.fabric.microsoft.com",
  "$compact.z$prefix.blob.fabric.microsoft.com"
)

foreach ($name in $names) {
  $addresses = Resolve-DnsName $name -Type A |
    Where-Object Type -eq A |
    Select-Object -ExpandProperty IPAddress
  $tcp = Test-NetConnection $name -Port 443 -InformationLevel Quiet
  [pscustomobject]@{ FQDN = $name; IP = ($addresses -join ","); TCP443 = $tcp }
}
```

Expected: each FQDN resolves to one of the private endpoint NIC addresses and
every TCP result is `True`. Public IP resolution is a hard failure.

For an Azure VM runner with managed identity, verify authenticated private API
access without printing the token:

```bash
WORKSPACE_A_ID=<private-workspace-guid>
WORKSPACE_API_FQDN=$(terraform output -raw workspace_api_fqdn)

TOKEN=$(curl -sS -H Metadata:true \
  'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https%3A%2F%2Fapi.fabric.microsoft.com' \
  | jq -r .access_token)

HTTP_CODE=$(curl -sS -o /tmp/workspace-private-check.json -w '%{http_code}' \
  -H "Authorization: Bearer $TOKEN" \
  "https://$WORKSPACE_API_FQDN/v1/workspaces/$WORKSPACE_A_ID")

unset TOKEN
echo "HTTP $HTTP_CODE"
jq '{id,displayName}' /tmp/workspace-private-check.json
test "$HTTP_CODE" = "200"
rm -f /tmp/workspace-private-check.json
```

Read both workspace communication policies from the authenticated operator
workstation. Both must remain `Allow` at this checkpoint:

```bash
TOKEN=$(az account get-access-token \
  --resource https://api.fabric.microsoft.com \
  --query accessToken -o tsv)

for workspace_id in <workspace-a-guid> <workspace-b-guid>; do
  curl -sS -H "Authorization: Bearer $TOKEN" \
    "https://api.fabric.microsoft.com/v1/workspaces/$workspace_id/networking/communicationPolicy" \
    | jq .
done

unset TOKEN
```

Expected pre-lockdown shape for both workspaces:

```json
{
  "inbound": {
    "publicAccessRules": {
      "defaultAction": "Allow"
    }
  },
  "outbound": {
    "publicAccessRules": {
      "defaultAction": "Allow"
    }
  }
}
```

A `401` indicates token/audience or authentication failure. A `403` indicates
the operator lacks workspace permissions. A `404` usually indicates the wrong
workspace/tenant or an unavailable endpoint; stop rather than treating an empty
response as `Allow`.

If apply is interrupted or Azure says a resource already exists, do not create
a duplicate. Compare `terraform state list`, the saved plan, and the live Azure
resource ID. Import the existing resource into the correct Phase B state only
after confirming its tenant/workspace/subresource, or delete the partial child
resource under an approved rollback and regenerate the plan.

**STOP:** keep Workspace A public access enabled if DNS, routing, endpoint
approval, five-IP output, TCP 443, authenticated API, policy, or no-drift
validation fails.

#### Expected Terraform result (reference screenshots)

> 📸 **Reference only — do not perform manually.** Expected Azure portal state
> **after** Phase B `terraform apply` succeeds.

**Workspace private endpoint** — target sub-resource **workspace**, connection
status **Approved**, in the Fabric spoke `pe-subnet`.

![Phase B — Fabric workspace private endpoint](docs/deployment-reference/tf-phaseb-01-fabric-private-endpoint.png)

**Private endpoint DNS configuration** — the workspace FQDNs
(`*.fabric.microsoft.com`) resolve to private spoke IPs via the
`privatelink.fabric.microsoft.com` zone.

![Phase B — PE DNS configuration](docs/deployment-reference/tf-phaseb-02-pe-dns-zone-group.png)

### 9. Prepare the customer SQL Server and OPDG hosts

> **Mode: 🟦 TERRAFORM (RUNNER) for the lab / 🟨 MANUAL for customer prod** — the
> `workloads/onprem-lab` root deploys the lab SQL + OPDG VMs. In a customer
> environment these are customer-owned production hosts (not Terraform). See
> *Expected Terraform result* screenshots at the end of this step.

Choose exactly one path.

#### Path A: customer production hosts (recommended)

Do **not** deploy `workloads/onprem-lab`. The database and data-platform teams
must provide:

- A supported production SQL Server reachable privately from OPDG.
- A dedicated least-privilege SQL login that can read only the approved source
  objects; store its credential in the customer secret manager.
- SQL TLS, backup, monitoring, patching, HA/DR, and ownership sign-off.
- At least two standard-mode OPDG hosts for production HA, sized and patched to
  customer standards. Microsoft recommends 8 cores, 8 GB+ RAM, and SSD.
- OPDG-to-SQL TCP connectivity and outbound gateway/Fabric rules from Step 3.
- No inbound internet rule for OPDG.

Record the server FQDN, database, source schema/table, gateway cluster name,
gateway administrators, recovery-key owner, and change IDs in the customer
worksheet.

**STOP:** the customer database and gateway owners must sign this handoff.

#### Path B: optional lab simulation only

Use this path only for a sandbox. It adds one SQL Developer VM and one OPDG VM
to an **existing** VNet/subnet named in the private variables. It creates both
on-prem-to-hub peerings and the workload firewall-transit UDR, but does not
create the simulated on-premises VNet, NAT/Bastion services, or private runner.
Read [workloads/onprem-lab/README.md](workloads/onprem-lab/README.md) before
planning this optional root.

**RUNNER**

```bash
cd /home/azureuser/lz/workloads/onprem-lab
terraform init -reconfigure -backend-config="$BACKEND_FILE"
terraform validate
rm -f onprem-lab.tfplan
terraform plan -var-file="$TFVARS_FILE" -out=onprem-lab.tfplan
terraform show -no-color onprem-lab.tfplan
# Human review and approval happen here.
terraform apply onprem-lab.tfplan
terraform plan -detailed-exitcode -var-file="$TFVARS_FILE"
```

Reference sandbox expectation: 20 resources on first deployment and final plan
exit code `0`.

**CHECK**

- SQL VM is running and SQL Server listens on TCP 1433.
- OPDG VM reaches SQL TCP 1433.
- The generated SQL login authenticates and reads exactly three sample rows.
- `C:\FabricHybridLab.ready` contains `SQL_READY`.
- `C:\FabricGatewayInstaller.ready` exists.
- `C:\Installers\GatewayInstall.exe` exists.
- OPDG resolves and reaches all five workspace endpoints on TCP 443.

Terraform stages the official gateway installer. It does not perform the
user-authenticated gateway registration.

#### Expected Terraform result (reference screenshots)

> 📸 **Reference only — do not perform manually.** In the **lab**, the
> `workloads/onprem-lab` root deploys these hosts. In a **customer** environment
> the SQL Server and OPDG hosts are customer-owned production systems — these
> screenshots then illustrate the expected shape, not a Terraform output.

**On-premises simulation resource group** — the lab SQL VM, OPDG VM, runner VM,
their NICs/NSGs/disks, VNet, and NAT.

![On-prem lab — resource group](docs/deployment-reference/tf-onprem-01-resource-group.png)

**Simulated on-prem SQL Server VM** — Windows Server, private IP on the on-prem
VNet, tagged `purpose: fabric-hybrid-simulation`.

![On-prem lab — SQL Server VM](docs/deployment-reference/tf-onprem-02-sql-vm.png)

### 10. Phase 5: install and register OPDG

> **Mode: 🟨 MANUAL (OPDG host)** — install and register the gateway on the OPDG
> Windows host. Terraform does not do this.
>
> **Reference lab status:** ✅ completed 2026-07-19. Gateway
> `azr-sbx-lab-0001-opdg` is registered in **West US 3** (tenant home region) and
> shows **Microsoft Fabric → Ready**. See the region gotcha below.

**OPDG VM interactive session**

The operator needs an approved interactive administration path such as private
RDP through Bastion, PAM, or the customer management network. Azure VM Run
Command cannot complete the organizational sign-in UI.

1. Sign in to the first OPDG host with a local/domain administrator account.
2. For the lab, run `C:\Installers\GatewayInstall.exe` as Administrator. For a
  customer host, download the current **standard-mode** installer from
  <https://go.microsoft.com/fwlink/?LinkId=2116849&clcid=0x409> through the
  approved software process. Do not install personal mode.
3. Keep the approved installation path, accept the terms, select **Install**,
  and wait for completion.
4. Open the **On-premises data gateway** app > **Diagnostics** > **Network ports
  test** > **Start new test**. The result must be `Completed (Succeeded)`.
  Export the detailed result to the customer change record.
5. If customer policy permits only HTTPS, open **Network**, enable **HTTPS
  mode**, select **Apply**, and rerun the network ports test. This restarts the
  gateway service.
6. Sign in with the approved organizational account that will administer the
  Fabric gateway.
7. Select **Register a new gateway on this computer**.
8. Enter the approved **standard-mode** cluster name. The reference lab uses
  `azr-sbx-lab-0001-opdg`; use the customer naming standard in production.
9. **Leave the region at the wizard's recommended value** — this is your Power
   BI/Fabric tenant's default (home) region, which the gateway *must* use to be
   usable by Fabric. Do **not** change it to match the capacity's Azure region.
   See the region gotcha note below.
10. Generate a strong recovery key using the approved secret process. Enter it
   in the installer and store it immediately in the customer secret manager.
   Microsoft cannot retrieve it. Never capture it in a screenshot.
11. For production HA, install the same supported gateway version on the second
   host, choose **Add to an existing gateway cluster**, select the cluster, and
   provide the recovery key through the approved secret-handling process.
12. In Fabric, open **Settings** > **Manage connections and gateways** >
   **On-premises data gateways**. Open the cluster and verify every intended
   member is `Online`.
13. Add the approved backup gateway administrators; do not leave a single
   personal account as the only administrator.

**Host check**

```powershell
Get-Service PBIEgwService | Format-List Name,Status,StartType
```

Expected: service status `Running`. Repeat the gateway app network test after
Firewall, proxy, or gateway-version changes.

Reference deployment screenshots — full step-by-step walkthrough (captured
2026-07-19). The reference gateway is named **`azr-sbx-lab-0001-opdg-new`**
(the plain `-opdg` name was already held by an earlier registration; pick an
unused cluster name).

**1. Accept the license terms**, keep the default install path, select Install.

![OPDG installer — accept terms](workloads/fabric/images/opdg-01-accept-terms.jpeg)

**2. Installation runs** (a minute or two).

![OPDG installing](workloads/fabric/images/opdg-02-installing.jpeg)

**3. Installation succeeds** — enter the administering email to register.

![OPDG installation complete](workloads/fabric/images/opdg-03-install-complete.jpeg)

**4. Sign in** with the approved organizational (work/school) account.

![OPDG sign-in account](workloads/fabric/images/opdg-04-signin-account.jpeg)

**5. Register a new gateway** on this computer.

![OPDG register new gateway](workloads/fabric/images/opdg-05-register-new-gateway.jpeg)

**6. Configure** the cluster name, **leave the recommended region** (here
**West US 3** — the tenant home region), and enter the recovery key (masked;
never screenshotted).

![OPDG config name + region](workloads/fabric/images/opdg-06-config-name-region.jpeg)

**7. Gateway online and Fabric-Ready** — the status panel must show
**Microsoft Fabric → Ready** (see the region gotcha below).

![OPDG online, Microsoft Fabric Ready](workloads/fabric/images/opdg-08-online-fabric-ready.jpeg)

**8. Network — HTTPS mode** (recommended) routes gateway traffic via Azure
Service Bus over HTTPS.

![OPDG network HTTPS mode](workloads/fabric/images/opdg-09-network-https-mode.jpeg)

**9. Service Settings** — the gateway runs as the `PBIEgwService` Windows
service.

![OPDG service settings](workloads/fabric/images/opdg-11-service-settings.jpeg)

**10. Cluster online in Fabric** — the cluster appears under Fabric **Manage
connections and gateways → On-premises data gateways** with status **Online**.

![OPDG cluster online in Fabric](workloads/fabric/images/opdg-10-fabric-cluster-online.jpeg)

> **⚠️ Region gotcha (important).** The gateway region must be your **Power BI /
> Fabric tenant's default (home) region** — *not* the Azure region of your Fabric
> capacity. In the reference lab the capacity is in **Israel Central**, but the
> tenant home region is **West US 3**. Registering the gateway in Israel Central
> produced **"Microsoft Fabric — Not available — Can't be used outside your
> default environment"**, making the gateway unusable by the workspace. The fix is
> to **uninstall and re-register the gateway, leaving the region at the
> recommended (tenant-default) value** — here **West US 3**. Accept the wizard's
> recommended region unless you have a specific reason not to.
>
> **Secret handling:** never show the recovery key, password, token, or connection
> secret in any screenshot. The recovery-key fields above are masked by design.

**Rollback:** before any data source uses the cluster, uninstall the failed
member or remove it from the cluster under an approved change. Do not discard a
recovery key for a cluster that owns live connections.

**STOP:** the network ports test, Windows service, cluster, and all intended HA
members must be healthy, and screenshots 09-11 must be approved.

### 11. Phase 6: create the private lakehouse and ingest SQL

> **Mode: 🟨 MANUAL (PORTAL)** — build the lakehouse and copy pipeline yourself in Microsoft Fabric.

**PORTAL: Workspace A**

1. Open Workspace A and select **New item** > **Lakehouse**.
2. Enter the approved lakehouse name. The reference lab uses
  `lh_onprem_private`. Select **Create**.
3. Refresh the workspace and verify the Lakehouse item exists in Workspace A.
4. Open **Settings** > **Manage connections and gateways** > **Connections** >
  **New** and select **SQL Server**.
5. Enter the customer SQL Server FQDN/IP and database. For the reference lab:
  - Server: `172.16.1.10`
  - Database: `FabricHybridLab`
6. Select the approved authentication type. For the reference lab only, use
  **Basic**, login `fabric_gateway`, and retrieve the password privately from
  an approved interactive session on the runner. Do not retrieve it through
  Azure VM Run Command, CI logs, chat, screenshots, or recorded/shared
  terminals. Customer production uses its approved secret manager and
  least-privilege identity; it does not use Terraform state as a credential
  delivery mechanism.
7. Under gateway, select the OPDG cluster registered in Step 10.
   - **Encryption note:** if the source SQL Server has no TLS certificate that
     the gateway trusts (common for lab/on-prem SQL), the wizard fails with
     *"We were unable to connect to the data source using an encrypted
     connection."* Uncheck **Use encrypted connection** and re-test. The
     reference lab connection is unencrypted for this reason; a customer with a
     trusted certificate should leave encryption enabled.
   - Select **Test connection**. Save only after the test succeeds.
8. In the Workspace A lakehouse editor, select **New copy job** (Copy job is the
   simplest managed-Delta ingestion path and lands a clean queryable table).
   Choose **SQL Server database** as the source and select the connection saved
   in Step 6-7 (shown as `[On-premises] <gateway name>`).
9. On **Choose data**, select the approved source table (`dbo.SalesOrders` in the
   lab). The gateway enumerates the table through the firewall-routed path.
10. On **Settings**, keep **Full copy** and a destination root of **Tables**
   (managed Delta). On **Map to destination**, confirm the target table
   (`dbo.SalesOrders`) and review column names/types.
11. Select **Save + Run** (or **Save**, then **Run** from the toolbar).
12. Open the **Results** tab and verify status `Succeeded`, `Rows read` and
   `Rows written` match, and jobs completed `1/1`. The lab expects exactly three
   rows read and written.
13. In the Lakehouse **Explorer**, refresh **Tables**, expand the `dbo` schema,
   and open the target table. Verify it renders as a normal Delta table (not
   **Unidentified**) and previews the expected rows. The lab expects exactly
   three rows.

**Screenshots (captured, firewall-routed run 2026-07-20):**

Private lakehouse created in Workspace A:

![Private lakehouse created](workloads/fabric/images/12-private-lakehouse-created.jpeg)

SQL Server connection online through the on-premises data gateway (unencrypted,
Basic auth, `[On-premises] azlab-gateway`):

![SQL connection through gateway](workloads/fabric/images/13-sql-connection-gateway.jpeg)

Copy job succeeded — 3 rows read, 3 rows written, `dbo.SalesOrders → dbo.SalesOrders`:

![Copy job succeeded](workloads/fabric/images/14-copyjob-succeeded-3rows.jpeg)

Clean queryable Delta table in the lakehouse (all 3 rows, 4 columns):

![Lakehouse SalesOrders Delta table](workloads/fabric/images/15-lakehouse-salesorders-delta.jpeg)

**Firewall transit evidence (this run):** with all on-prem egress forced through
the Azure hub firewall (UDR), the copy-job run at 09:33-09:34 (GMT+3) was
observed in the firewall logs, proving both control- and data-plane traffic
traversed the firewall:

- **Application rule (Allow):** gateway → `*.servicebus.windows.net`
  (control channel) and `wu3.frontend.clouddatahub.net` (Fabric copy data plane).
- **Network rule (Allow):** gateway `172.16.x` → Fabric private endpoint
  `10.2.0.7:443` — 14 TCP connections during the run window (06:33:52-06:34:00
  UTC), matching the data-plane write to OneLake.
- Windows/Defender/telemetry FQDNs were **Denied** by the catch-all, confirming
  least-privilege egress. See `docs/fabric-opdg-firewall-rules.md` for the full
  rule set and validated FQDN list.

Record the lakehouse, SQL analytics endpoint, copy job, connection IDs, run ID,
start/end time, and row counts.

<details>
<summary><b>Copy job wizard walkthrough (step-by-step screenshots)</b></summary>

1. In the lakehouse, start **New copy job**:

   ![New copy job](workloads/fabric/images/p6-01-new-copy-job.jpeg)

2. **Choose data source** — select **SQL Server database**:

   ![Choose data source](workloads/fabric/images/p6-02-choose-data-source.jpeg)

3. Select the on-premises data gateway (`[On-premises] azlab-gateway`):

   ![Select gateway](workloads/fabric/images/p6-03-select-gateway.jpeg)

4. Complete the connection (server, database, Basic auth, `fabric_gateway`).
   If the source SQL has no trusted TLS cert, uncheck **Use encrypted
   connection** (see note above):

   ![Connection filled](workloads/fabric/images/p6-04-connection-filled.jpeg)

5. **Choose data** — the gateway enumerates `dbo.SalesOrders` through the
   firewall-routed path:

   ![Choose data](workloads/fabric/images/p6-05-choose-data.jpeg)

6. **Settings** — keep **Full copy** and destination root **Tables** (managed
   Delta):

   ![Settings full copy](workloads/fabric/images/p6-06-settings-full-copy.jpeg)

7. **Map to destination** — confirm `dbo.SalesOrders` → `dbo.SalesOrders`:

   ![Map to destination](workloads/fabric/images/p6-07-map-to-destination.jpeg)

8. **Review + save** — confirm the summary, then **Save + Run**:

   ![Review and save](workloads/fabric/images/p6-08-review-and-save.jpeg)

</details>

**Rollback:** disable the schedule/trigger, delete only the failed pipeline run
artifacts and destination table created by this change, then correct the
connection or mapping. Do not delete a shared customer connection without owner
approval.

**STOP:** ingestion must pass before Workspace A public access is restricted.

### 12. Phase 7: build the public semantic model and report

> **Mode: 🟨 MANUAL (PORTAL)** — build the semantic model and report yourself in Microsoft Fabric.

**PORTAL: Workspace B**

This is a compatibility gate. Workspace-level Private Link support varies by
Fabric item and connection mode. Confirm the selected semantic-model pattern is
supported in the customer's tenant before committing to it. Sharing an F
capacity does not grant Workspace B network access to Workspace A.

1. Obtain Workspace A's SQL analytics endpoint from the Lakehouse settings
  (Lakehouse > **Settings** > **SQL analytics endpoint** > copy the connection
  string, e.g. `<hash>.datawarehouse.fabric.microsoft.com`). The endpoint's
  database name equals the lakehouse name (`lh_onprem_private` in the lab).
2. In Workspace B, select **New item** > **Semantic model** (or **Report** >
  **Get data**). Choose **Get Data** > **SQL Server database**.
3. Enter the SQL analytics endpoint as **Server** and the lakehouse name as
  **Database**. For **initial build while Workspace A is still public**, leave
  **Data gateway** = `(none)` and set **Authentication kind** =
  **Organizational account** (Entra/OAuth). Do not use Basic/SQL auth here.
  > ⚠️ **This cloud connection stops refreshing once Workspace A is locked down
  > in Phase 9** (fails with `CrossWorkspaceRequestNotAllowed`). To keep the
  > public model refreshing against a private Workspace A you MUST bind it to a
  > **data gateway** using the workspace-private `z{xy}` connection string. See
  > [Appendix A](#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a)
  > and do it before/after lockdown per that runbook.
4. Select **Next**, choose the source table (`dbo.SalesOrders`), confirm the
  preview shows the expected rows, then **Transform data** > **Create a report**
  (Import). This creates the semantic model and report in Workspace B.
5. Name the semantic model (lab: `sm_salesorders_public`) and confirm the target
  workspace is **Workspace B (public)**. Select **Create**.
6. Build a table/visual that proves the expected rows, then **Save** the report
  to **Workspace B** (lab: `rpt_salesorders_public`). Verify it renders the rows
  in reading view.
7. Open **Semantic model settings** > **Gateway and cloud connections**.
   - Before Workspace A lockdown, confirm the **Cloud connections** section
     lists the SQL analytics endpoint data source with a green check.
   - For post-lockdown refresh, enable **Gateway connections**, select the
     running lab OPDG cluster (`azlab-gateway`), and map the source to
     `sql-fabric-private-za2`. Follow
     [Appendix A](#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a)
     for the workspace-specific private SQL endpoint configuration.
8. Under **Refresh** (or via the model's **Refresh now**), trigger a refresh.
  Open **Refresh history** and verify the run shows `Completed`. Import mode
  means Workspace B holds its own copy of the data, so the public report keeps
  working after Workspace A is locked down in Phase 9.

**Screenshots (captured, 2026-07-20):**

Semantic model cloud connection — the public model in Workspace B binds to
Workspace A's SQL analytics endpoint as a cloud data source before lockdown:

![Public semantic model cloud connection](workloads/fabric/images/16-public-semantic-model-cloud-connection.jpeg)

Post-lockdown gateway binding — **Gateway connections** is On, `azlab-gateway`
is running, and the private SQL analytics endpoint maps to
`sql-fabric-private-za2`:

![Public semantic model bound to OPDG](workloads/fabric/images/16-public-semantic-model-gateway-binding.jpeg)

Refresh history — Import refresh `Completed` (initial web-modeling load + a
manual refresh):

![Public semantic model refresh succeeded](workloads/fabric/images/17-public-semantic-model-refresh-succeeded.jpeg)

Public report in Workspace B rendering the SalesOrders rows read from the
private lakehouse (Adventure Works 2,199.99 / Contoso Retail 1,250.00 /
Fabrikam Stores 875.50; total 4,325.49):

![Public report SalesOrders](workloads/fabric/images/18-public-report-salesorders.jpeg)

> **Design note (Import vs DirectQuery):** the lab uses **Import** so Workspace B
> caches the data and does not need live network access to Workspace A after
> refresh — this is what lets Workspace A be restricted to private access in
> Phase 9. If the customer requires **DirectQuery** to a restricted Workspace A,
> that is the compatibility gate: confirm workspace-level Private Link is
> supported for the chosen connection mode before committing. Direct Lake is not
> the fallback for an unsupported restricted-workspace path.

<details>
<summary><b>Get Data / semantic model + report walkthrough (step-by-step screenshots)</b></summary>

1. In Workspace B, **New item** > **Semantic model** (or **Report**) > **Get
   Data**:

   ![Get Data](workloads/fabric/images/p7-01-get-data.jpeg)

2. Choose **SQL Server database** and open the connect form:

   ![SQL connect form](workloads/fabric/images/p7-02-sql-connect-form.jpeg)

3. Enter the SQL analytics endpoint as **Server**, the lakehouse name as
   **Database**, leave **Data gateway = (none)**, set **Authentication kind =
   Organizational account** (the signed-in Fabric user authenticates — no
   gateway, no Basic auth):

   ![Organizational account auth](workloads/fabric/images/p7-03-org-account-auth.jpeg)

4. The endpoint enumerates its tables cross-workspace — select `SalesOrders`:

   ![Navigator SalesOrders](workloads/fabric/images/p7-04-navigator-salesorders.jpeg)

5. Preview confirms the 3 rows read from the private lakehouse:

   ![Source preview](workloads/fabric/images/p7-05-source-preview-3rows.jpeg)

6. **Transform data** opens Power Query (Import) — 3 rows, 4 columns:

   ![Power Query editor](workloads/fabric/images/p7-06-power-query-editor.jpeg)

7. **Create a report** — name the semantic model and target **Workspace B
   (public)**:

   ![Create report naming](workloads/fabric/images/p7-07-create-report-naming.jpeg)

8. Build a table visual showing the rows:

   ![Table visual](workloads/fabric/images/p7-08-table-visual-3rows.jpeg)

9. **Save** the report — select **Workspace B (public)** (the dialog may default
   to the private workspace; switch it):

   ![Save report dialog](workloads/fabric/images/p7-09-save-report-dialog.jpeg)

</details>

Record semantic model ID, report ID, connection mapping, refresh ID, refresh
time, mode, and row count.

If the chosen item or connection mode is unsupported with workspace-level
Private Link, stop and return to architecture review. Do not weaken Workspace A
network policy to make an unsupported design appear to work.

**STOP:** connection binding and refresh must succeed before lockdown.

### 13. Phase 8: final pre-lockdown validation

> **Mode: ⬜ VALIDATE (CHECK)** — read-only end-to-end validation; no changes.

**CHECK**

- [ ] Five Workspace A FQDNs resolve from OPDG to the five addresses returned by
  `workspace_private_endpoint_ips`; none resolve publicly.
- [ ] TCP 443 succeeds to all five workspace FQDNs.
- [ ] OPDG reaches SQL on the approved port and authenticates with the intended
  least-privilege identity.
- [ ] SQL query returns the approved source row count.
- [ ] Authenticated Workspace A API request returns HTTP `200` privately.
- [ ] Private endpoint and connection remain `Succeeded`/`Approved`.
- [ ] Copy pipeline run succeeds through OPDG with matching row counts.
- [ ] Workspace B semantic-model refresh succeeds through the bound connection.
- [ ] Workspace A and B communication policies still show inbound/outbound
  public access `Allow`.
- [ ] All three Terraform roots return plan exit code `0`.
- [ ] Rollback operator is online and has Workspace A Admin.

Store command output, pipeline/refresh IDs, timestamps, and screenshots in the
change record. This is the final go/no-go review.

**STOP:** any failure keeps Workspace A public access enabled.

### 14. Phase 9: restrict Workspace A last

> **Mode: 🟨 MANUAL (PORTAL)** — apply the final public-access restriction yourself in Microsoft Fabric.

**PORTAL: Workspace A**

1. Perform this action from a client that already proved private Workspace A
  access. Keep a second Workspace A Admin available for rollback.
2. Open **Workspace settings** > **Inbound networking**.
3. Record the current `Allow` state.
4. Select **Allow connections from selected networks and workspace level
   private links**.
5. Select **Apply**. Wait up to 30 minutes; do not declare success while the UI
  shows unapplied or propagating changes.
6. Refresh and verify the restricted selection persists.
7. Capture `19-private-workspace-inbound-restricted.jpeg`.
8. Repeat every Step 13 private, pipeline, gateway, and refresh test.
9. From a client outside the private/allowed network, verify Workspace A is
  denied.
10. Verify Workspace B remains publicly reachable under Entra Conditional
   Access.

**Screenshot (captured 2026-07-20):** Workspace A inbound networking persisted as
*"Allow connections from selected networks and workspace level private links"*
(public addresses Not configured = private-link only):

![Workspace A inbound restricted](workloads/fabric/images/19-private-workspace-inbound-restricted.jpeg)

**Post-lockdown re-validation results (this run):**

- ✅ **Copy job (on-prem -> Workspace A) still succeeds** through the OPDG over
  the workspace private endpoint (public access = Deny) — instance completed,
  3 rows.
- ⚠️ **Public Workspace B semantic-model refresh fails** with
  `CrossWorkspaceRequestNotAllowed` while it uses the ordinary cloud connection.
  This is expected (Fabric access protector) and is fixed by binding the model
  to a data gateway — see
  [Appendix A](#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a).

**Required fix — bind the Workspace B model to the gateway (do this now):**

This keeps the public report refreshing while Workspace A stays private. Do it
right after lockdown. Full root cause, DNS chain, and Microsoft citations are in
[Appendix A](#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a).

1. **Build the workspace-private server name.** Take Workspace A's object ID,
   delete the dashes, and read the **first two characters**. Prefix them with the
   literal letter `z` to get the label `z{xy}` (lab: ID `a20cea33...` -> `za2`).
   Insert `.z{xy}` into the SQL analytics endpoint host, between the hash and
   `datawarehouse`, leaving everything else unchanged:
   `<hash>.z{xy}.datawarehouse.fabric.microsoft.com` (lab:
   `yzg45...af3lh5a.za2.datawarehouse.fabric.microsoft.com`).
2. **Create the gateway connection.** In **Manage connections and gateways** >
   **+ New**, choose **On-premises**, pick the OPDG cluster (lab:
   `azlab-gateway`), set **Connection type = SQL Server**, **Server** = the
   `z{xy}` host from step 1, **Database** = the lakehouse name (lab:
   `lh_onprem_private`), and **Authentication = OAuth 2.0**. Leave **Skip test
   connection** unchecked; the test must pass.
3. **Bind the model to the connection.** In **Workspace B** > semantic model >
   **Settings** > **Gateway and cloud connections**, enable **Gateway
   connections** and map the SQL source to the connection from step 2. (API
   equivalent: `Default.BindToGateway`; if the model still points at the public
   host, first repoint its datasource server to the `z{xy}` host via
   `Default.UpdateDatasources` so both server strings match.)
4. **Refresh and verify.** Trigger a refresh and confirm it shows **Completed**
   with no `CrossWorkspaceRequestNotAllowed`.

**End-to-end proof — new on-prem data reaching the public report while A stays
private (2026-07-20):** after applying the gateway fix above, a new on-prem row
(`Northwind Traders`, 1500.00) was pushed through both hops and appeared in the
public report:

![Public report shows the new 4th row after lockdown](workloads/fabric/images/20-public-report-4th-row-after-lockdown.jpeg)

Key operational notes from this proof (details in the fix doc):

- Copy job control for the now-private Workspace A must be triggered from **inside
  the allowed VNet** (the runner resolves `...za2.w.api...` to the private
  endpoint) or via a **scheduled** run — public-client API/portal job control is
  denied by the inbound policy.
- Allow for the **SQL analytics endpoint sync lag**: the first refresh after the
  copy may still show old data; a second refresh after the metadata sync shows
  the new rows.

API equivalent for an approved automation path:

```bash
TOKEN=$(az account get-access-token \
  --resource https://api.fabric.microsoft.com \
  --query accessToken -o tsv)

curl -sS -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  "https://api.fabric.microsoft.com/v1/workspaces/$WORKSPACE_A_ID/networking/communicationPolicy" \
  -d '{"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}' | jq .

unset TOKEN
```

**Rollback from a private/allowed client:** return to **Workspace settings** >
**Inbound networking**, select the option that allows public connections, and
select **Apply**. API rollback changes `defaultAction` to `Allow`. Wait for
propagation, verify public recovery, then diagnose DNS, endpoint, routing,
gateway, and item compatibility before retrying.

> ⚠️ **Cross-workspace refresh gate (verified 2026-07-20):** after this lockdown,
> the OPDG copy job (on-prem -> Workspace A) keeps working over the private
> endpoint, but a public **Workspace B** semantic-model refresh that reads
> Workspace A over an ordinary **cloud connection** fails with
> `CrossWorkspaceRequestNotAllowed`. This is by design (Fabric access protector).
> The supported fix is to bind the Workspace B model to a **data gateway** (VNet
> or the existing OPDG) using the workspace-private `z{xy}` datawarehouse
> connection string. Full root-cause, Microsoft citations, and step-by-step fix:
> [Appendix A](#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a).

**STOP:** success requires private access and data workflows to pass, public
Workspace A access to fail, Workspace B to remain available under CA, and the
restricted screenshot/evidence to be approved.

### 15. Pause nonproduction resources when idle

> **Mode: 🟨 MANUAL (PORTAL)** — pause/resume capacity and stop lab VMs yourself.

**LAPTOP**

1. Confirm no pipeline, refresh, Spark job, or interactive user is active.
2. Pause nonproduction F capacity if customer policy permits.
3. Deallocate only customer-approved nonproduction VMs. Production OPDG/SQL HA
   hosts normally remain running.
4. Verify all VM states and the capacity state.

```bash
FABRIC_CAPACITY_ID=<full-fabric-capacity-resource-id>

az rest --method post \
  --url "https://management.azure.com${FABRIC_CAPACITY_ID}/suspend?api-version=2023-11-01"

for vm_name in <approved-nonproduction-vm-names>; do
  az vm deallocate \
    --subscription "$WORKLOADS_SUBSCRIPTION_ID" \
    --resource-group <vm-resource-group> \
    --name "$vm_name" \
    --no-wait
done

az rest --method get \
  --url "https://management.azure.com${FABRIC_CAPACITY_ID}?api-version=2023-11-01" \
  --query '{name:name,state:properties.state,provisioning:properties.provisioningState}' \
  -o json
```

Pausing F2 stops Fabric compute billing. VM deallocation stops VM compute
billing. Azure Firewall, NAT Gateway, disks, public IPs, Private
Endpoints, DNS, state storage, and OneLake storage continue to incur charges.

## Layer 3 — Foundry workload

Layer 3 extends the shared Layer 1 platform with a private Foundry spoke,
network-injected Agent Service, private supporting PaaS services, and APIM
publication. It consumes the private Azure Monitor foundation already deployed
in Stage 40 rather than creating another AMPLS or duplicate Monitor DNS zones.

### 16. Validate Layer 3 prerequisites

> **Mode: ⬜ VALIDATE (LAPTOP/RUNNER)** — no workload resources created.

The reference deployment uses Microsoft Template 19, pinned in
`workloads/foundry/UPSTREAM_COMMIT`, with these approved values:

| Setting | Reference value |
|---|---|
| Region | Sweden Central |
| Foundry spoke | `10.3.0.0/16` |
| Agent / PE / tools subnets | `10.3.0.0/24`, `10.3.1.0/24`, `10.3.2.0/24` |
| APIM integration subnet | `10.3.3.0/27` |
| Search | Standard (S1), two replicas, one partition |
| Model | gpt-5-mini `2025-08-07`, GlobalStandard, capacity 40 |
| Hosted Agent | Responses protocol with private AI Search grounding |

Verify providers, quota, APIM/Search availability, CIDR overlap, and Terraform
`>=1.10`. The reference runner was upgraded to Terraform `1.13.5` after SHA256
verification. Sweden Central supports Hosted Agents, Class A injection, Search
agentic retrieval, and APIM Standard v2. Premium v2 new-instance capacity is
currently restricted in this region.

**Azure AI Search service quota:** regional SKU availability does not guarantee
subscription quota. Query the Search usage endpoint or open **Azure portal >
Quotas > Overview > Search**, select the workload subscription, and filter the
region to **Sweden Central**. Record the target subscription's Standard-tier
usage and limit before deployment. Standard Agent setup does not require S3;
use the approved target tier with the required replicas and partitions.

**STOP:** do not plan until every provider is Registered, model quota exists,
Search Standard quota is available, `10.3.0.0/16` is non-overlapping, and the
private runner can reach its backend and Terraform Registry.

### 17. Deploy private Foundry foundation

> **Mode: 🟦 TERRAFORM (RUNNER)** — Template 19 adaptation with isolated state
> key `workloads-foundry.tfstate`.

```bash
cd /home/azureuser/lz/workloads/foundry
export ARM_USE_MSI=true
export FOUNDRY_BACKEND_FILE=../../_private/backend.hcl
export FOUNDRY_TFVARS_FILE=../../_private/foundry.private.tfvars
terraform init -reconfigure -backend-config="$FOUNDRY_BACKEND_FILE"
terraform validate
terraform plan -var-file="$FOUNDRY_TFVARS_FILE" -out=foundry.tfplan
terraform show -no-color foundry.tfplan
# Review: no destroy/replacement/public-access changes.
terraform apply foundry.tfplan
terraform plan -detailed-exitcode -var-file="$FOUNDRY_TFVARS_FILE"
```

The shared backend remains authoritative because the Foundry root has its own
`workloads-foundry.tfstate` key. Use the dedicated Layer 3 tfvars file rather
than the broader Layer 1/2 overlay. Verify the active subscription immediately
before init. Do not place operator UPNs in the Foundry infrastructure tfvars.

This root owns the spoke/peerings/UDR, BYO Storage/Cosmos/Search, private ACR,
Foundry account/project/model, connections/RBAC, both capability hosts, private
endpoints/DNS, and private Application Insights/AMPLS association.

**Required screenshots (capture final refreshed state):**

Layer 3 evidence follows the same standard as the local
`Azure-AI-Foundry-Networking` reference repository: PNG, at least 1600 px wide,
one verifiable control per image, irrelevant browser canvas cropped, and
subscription IDs, tenant IDs, object IDs, keys, tokens, and connection strings
redacted. Resource names, role names, FQDN patterns, subnet delegation, status,
and error text remain visible because they are instructional evidence.

Capture and retain the complete evidence set below. A phase is not documented
as complete until every applicable file exists and is embedded after its related
validation text.

| # | Save as | Required evidence |
|---|---|---|
| 1 | `l3-01a-foundry-subnet-inventory.png` | Agent, PE, and MCP/tools subnet names and CIDRs |
| 2 | `l3-01b-agent-subnet-delegation.png` | `Microsoft.App/environments`, join action, Succeeded |
| 3 | `l3-02a-foundry-hub-peering.png` | Forwarded traffic, Connected, FullyInSync, Succeeded |
| 4 | `l3-02b-firewall-default-route.png` | `0.0.0.0/0`, VirtualAppliance, `10.0.0.4`, Succeeded |
| 5 | `l3-03a-private-endpoint-inventory.png` | Storage, Cosmos DB, Search, Foundry, and ACR PEs |
| 6 | `l3-03b-private-endpoint-connections.png` | Approved connection state and expected subresources |
| 7 | `l3-03c-private-dns-resolution.png` | Redacted private FQDN resolution to PE addresses |
| 8 | `l3-04a-foundry-public-access-disabled.png` | Foundry public access Disabled |
| 9 | `l3-04b-foundry-network-injection.png` | Redacted delegated `agent-subnet` binding |
| 10 | `l3-05a-search-managed-identity.png` | Search system identity On; object ID redacted |
| 11 | `l3-05b-search-standard-capacity.png` | Standard tier, two replicas, one partition |
| 12 | `l3-05c-search-network-isolation.png` | Public access/local auth disabled and PE Approved |
| 13 | `l3-05d-search-project-roles.png` | Search Service Contributor and Index Data Contributor |
| 14 | `l3-06a-project-managed-identity.png` | Foundry project system identity; object ID redacted |
| 15 | `l3-06b-project-connections.png` | Storage, Cosmos DB, and Search project connections |
| 16 | `l3-06c-account-capability-host.png` | Account Agents capability host Succeeded and subnet |
| 17 | `l3-06d-project-capability-host.png` | Project host Succeeded with all three BYO connections |
| 18 | `l3-06e-project-resource-roles.png` | Required Storage/Cosmos/Search/ACR project-MI roles |
| 19 | `l3-07a-foundry-appinsights-public-restricted.png` | App Insights ingestion/query public inbound restricted |
| 20 | `l3-07b-foundry-appinsights-ampls.png` | Central AMPLS scoped-resource association |
| 21 | `l3-07c-monitoring-reader-roles.png` | Project-MI monitoring reader roles on App Insights/LAW |
| 22 | `l3-08a-apim-private-network.png` | Standard v2, public disabled, PE, VNet integration |
| 23 | `l3-08b-apim-managed-identity.png` | APIM system identity and backend RBAC |
| 24 | `l3-09a-apim-model-agent-apis.png` | Model and Hosted Agent API inventory |
| 25 | `l3-09b-apim-ai-policies.png` | MI auth, token metrics/limits, safety, rate limiting, cache |
| 26 | `l3-10a-hosted-agent-active.png` | Active version, Responses protocol, image, project |
| 27 | `l3-10b-hosted-agent-identity.png` | Hosted Agent identity and least-privilege roles |
| 28 | `l3-11a-private-search-grounded-response.png` | Successful grounded response through governed path |
| 29 | `l3-11b-agent-byo-state.png` | Resulting Storage/Search/Cosmos data artifacts |
| 30 | `l3-12a-private-dns-validation.png` | Foundry/Search/Storage/Cosmos/ACR/APIM/Monitor private DNS |
| 31 | `l3-12b-firewall-runtime-rules.png` | Runtime, identity, MCR, evaluation, monitoring, APIM rules |
| 32 | `l3-12c-private-telemetry.png` | Managed-identity telemetry in private App Insights |
| 33 | `l3-12d-terraform-no-drift.png` | All Layer 3 roots return detailed exit code `0` |
| 34 | `l3-13a-model-deployment.png` | gpt-5-mini version, GlobalStandard SKU, capacity, Succeeded |
| 35 | `l3-13b-storage-network-isolation.png` | Storage public access disabled and local keys disabled |
| 36 | `l3-13c-storage-private-endpoint.png` | Storage Blob PE Approved and DNS integration |
| 37 | `l3-13d-cosmos-network-isolation.png` | Cosmos public/local auth disabled and private endpoint |
| 38 | `l3-13e-acr-private-access.png` | Premium ACR public access disabled and PE Approved |
| 39 | `l3-13f-central-private-dns.png` | Foundry/Search/Cosmos/ACR zones linked to hub and spoke |
| 40 | `l3-13g-firewall-diagnostics.png` | Firewall allow/deny diagnostics flowing to central LAW |

**Foundry subnet inventory and delegation** — the Agent and MCP/tools subnets
are delegated to `Microsoft.App/environments`, while the PE subnet remains
dedicated to private endpoints. Both delegated subnets use the Foundry route
table.

![Layer 3 — Foundry subnet inventory](workloads/foundry/images/l3-01a-foundry-subnet-inventory.png)

![Layer 3 — Agent subnet delegation](workloads/foundry/images/l3-01b-agent-subnet-delegation.png)

**Hub transit** — the Foundry-to-hub peering is Connected/FullyInSync with
forwarded traffic enabled, and `0.0.0.0/0` routes to Azure Firewall `10.0.0.4`.

![Layer 3 — Foundry-to-hub peering](workloads/foundry/images/l3-02a-foundry-hub-peering.png)

![Layer 3 — default route to hub firewall](workloads/foundry/images/l3-02b-firewall-default-route.png)

**Foundry resource inventory** — the resource group contains the private Foundry
account/project, BYO Storage/Cosmos/Search, Premium ACR, VNet, route table,
Application Insights, and private endpoints.

![Layer 3 — Foundry resource inventory](workloads/foundry/images/l3-00-foundry-resource-inventory.png)

**Private endpoint inventory** — all five workload private endpoints are in
Sweden Central.

![Layer 3 — private endpoint inventory](workloads/foundry/images/l3-03a-private-endpoint-inventory.png)

**Foundry private endpoint connection** — the representative endpoint is in the
`pe-subnet`, targets the Foundry `account` subresource, and is
`Succeeded`/`Approved`. ARM validation confirms the Storage `blob`, Cosmos
`Sql`, Search `searchService`, and ACR `registry` endpoints are also Approved.

![Layer 3 — approved Foundry private endpoint](workloads/foundry/images/l3-03b-private-endpoint-connections.png)

**Foundry public access** — disabled, making private endpoints the exclusive
inbound path.

![Layer 3 — Foundry public access disabled](workloads/foundry/images/l3-04a-foundry-public-access-disabled.png)

**Foundry network injection** — Standard Agent is bound to the delegated
`agent-subnet`; subscription/resource-group details are redacted.

![Layer 3 — Foundry network injection](workloads/foundry/images/l3-04b-foundry-network-injection.png)

**Search managed identity** — system-assigned identity is On; identifiers are
redacted.

![Layer 3 — Search managed identity](workloads/foundry/images/l3-05a-search-managed-identity.png)

**Search capacity** — Standard tier, two replicas, one partition, and two search
units, providing the read SLA baseline.

![Layer 3 — Search Standard capacity](workloads/foundry/images/l3-05b-search-standard-capacity.png)

**Search network and API isolation** — public network access is Disabled and API
access control is set to role-based access only.

![Layer 3 — Search public access disabled](workloads/foundry/images/l3-05c-search-network-isolation.png)

![Layer 3 — Search role-based API access](workloads/foundry/images/l3-05c2-search-local-auth-disabled.png)

> **Screenshot placeholder — `l3-05d-search-project-roles.png`**: project
> identity has Search Service Contributor and Search Index Data Contributor.

**Foundry project identity** — system-assigned identity is On; identifiers are
redacted.

![Layer 3 — Foundry project identity](workloads/foundry/images/l3-06a-project-managed-identity.png)

**Project BYO connections** — each connection uses Entra ID (`AAD`) and points
to the customer-owned service endpoint.

![Layer 3 — Storage project connection](workloads/foundry/images/l3-06b1-storage-connection.png)

![Layer 3 — Cosmos DB project connection](workloads/foundry/images/l3-06b2-cosmos-connection.png)

![Layer 3 — Search project connection](workloads/foundry/images/l3-06b3-search-connection.png)

**Capability hosts** — the account Agents host is bound to the delegated subnet;
the project host is Succeeded and references Storage, Cosmos DB, and Search.

![Layer 3 — account capability host](workloads/foundry/images/l3-06c-account-capability-host.png)

![Layer 3 — project capability-host connections](workloads/foundry/images/l3-06d-project-capability-host.png)

![Layer 3 — project capability-host status](workloads/foundry/images/l3-06d2-project-capability-status.png)

> **Screenshot placeholder — `l3-06e-project-resource-roles.png`**: capture the
> complete project identity role set on Storage, Cosmos DB, Search, ACR, App
> Insights, and Log Analytics.

**Private monitoring** — Application Insights public ingestion/query are
restricted and the component is associated with the central AMPLS.

![Layer 3 — Application Insights public access restricted](workloads/foundry/images/l3-07a-foundry-appinsights-public-restricted.png)

![Layer 3 — Application Insights central AMPLS association](workloads/foundry/images/l3-07b-foundry-appinsights-ampls.png)

**STOP:** both capability hosts and all private endpoints must be Succeeded,
private DNS/TCP tests must pass, and Terraform must return `0` before Step 18.

### 18. Deploy private APIM AI Gateway

> **Mode: 🟦 TERRAFORM (RUNNER)** — isolated state key
> `35-ai-gateway.tfstate`.

```bash
cd /home/azureuser/lz/platform/35-ai-gateway
terraform init -reconfigure -backend-config="$FOUNDRY_BACKEND_FILE"
terraform validate
export AI_GATEWAY_TFVARS_FILE=../../_private/ai-gateway.private.tfvars
terraform plan -var-file="$AI_GATEWAY_TFVARS_FILE" \
  -var=apim_public_network_access_enabled=true \
  -out=ai-gateway-bootstrap.tfplan
terraform show -no-color ai-gateway-bootstrap.tfplan
terraform apply ai-gateway-bootstrap.tfplan

# Mandatory convergence after the Gateway private endpoint is created.
terraform plan -var-file="$AI_GATEWAY_TFVARS_FILE" -out=ai-gateway.tfplan
terraform show -no-color ai-gateway.tfplan
terraform apply ai-gateway.tfplan
terraform plan -detailed-exitcode -var-file="$AI_GATEWAY_TFVARS_FILE"
```

Azure requires public network access during initial APIM activation. The first
apply is therefore a bootstrap phase only. The second apply must disable public
network access, and the final detailed-exit-code plan must return `0`.

The root creates APIM Standard v2, its dedicated delegated/NSG/UDR subnet,
inbound Private Endpoint, central DNS, managed identity, LAW diagnostics, and
Application Insights logger. Model/agent APIs and FinOps enforcement are added
after the Hosted Agent endpoint exists.

> **Screenshot placeholder — `l3-08-apim-private-network.png`**: Standard v2,
> public access disabled, inbound PE Approved, outbound VNet integration enabled.

> **Screenshot placeholder — `l3-09-apim-ai-policies.png`**: model/agent APIs,
> managed-identity backend, token limits/metrics, content safety, rate limits,
> and semantic-cache policy where supported.

### 19. Deploy the Foundry Hosted Agent

> **Mode: 🟦 AZD (PRIVATE CLIENT)** — agent code/version lifecycle, not Terraform.

The first agent is Python, Responses protocol, gpt-5-mini, and private AI Search
grounding. Deploy from a client with private Foundry/ACR DNS and data-plane
reachability. Authenticate interactively with `azd auth login`; never automate
or record that browser login.

> **Screenshot placeholder — `l3-10-hosted-agent-active.png`**: Hosted Agent
> version Active with Responses protocol, image/runtime, identity, and private
> project visible; do not expose secrets.

> **Screenshot placeholder — `l3-11-hosted-agent-search-response.png`**:
> successful grounded response through private Search and the governed APIM path.

### 20. Run final Layer 3 validation

| Area | Pass condition |
|---|---|
| Public access | Disabled on every PaaS service that supports it |
| DNS | Foundry/Search/Storage/Cosmos/ACR/APIM/Monitor FQDNs resolve privately |
| Routing | Agent/tools/APIM egress traverses the hub firewall; private endpoints remain direct |
| Identity | Project, Hosted Agent, and APIM identities have least-privilege roles |
| BYO state | Agent files, vector data, and conversation state appear in Storage/Search/Cosmos |
| Monitoring | Managed-identity OpenTelemetry reaches private Application Insights |
| Agent | Responses invocation and Search grounding succeed |
| APIM | Private invocation, token metric, throttling, and content policy tests pass |
| Terraform | Foundry, gateway, firewall, and platform roots return detailed exit code `0` |

> **Screenshot placeholder — `l3-12-layer3-final-validation.png`**: final private
> invocation plus supporting DNS/telemetry evidence, with tokens and identifiers
> redacted as required.

For implementation ownership and upstream deviations, see
[workloads/foundry/README.md](workloads/foundry/README.md) and
[platform/35-ai-gateway/README.md](platform/35-ai-gateway/README.md).

## Evidence acceptance criteria

For every manual portal action, capture the **final applied state after a page
refresh**, not only the form before Save/Apply. Each evidence item must include:

- Change/ticket ID, operator, UTC timestamp, tenant/subscription/workspace, and
  action performed.
- Screenshot or command/API output proving the expected state.
- Resource/item IDs and the validation result.
- No password, bearer token, recovery key, cookie, SAS, access key, private
  connection secret, or unrelated personal/tenant data.
- Approver and explicit go/no-go result for the next STOP gate.

The embedded screenshots are reference examples from the reference lab. Customer
evidence must be captured in the customer environment. In the reference lab,
Layers 1–2 have been executed and their screenshots captured (Layer 1 01-14,
OPDG opdg-01..11, Phase 6 12-15 + walkthrough, Phase 7 16-18 + walkthrough,
Phase 9 lockdown 19, and end-to-end proof 20). Layer 3 Foundry foundation
evidence is captured in the screenshot matrix above; APIM and Hosted Agent
evidence remains incomplete. A customer run must re-capture all released-layer
evidence in the customer tenant.

## Rollback order

Rollback in reverse dependency order. Never destroy a shared hub, backend,
capacity, connection, or gateway because one workload test failed.

For Layer 3, first disable APIM publication, then stop/remove only new agents.
Destroy the isolated `platform/35-ai-gateway` state before the
`workloads/foundry` state; the latter removes Application Insights integration,
private endpoints, BYO dependencies, and the Foundry spoke in reverse dependency
order. Do not remove shared hub firewall, DNS, Log Analytics, or AMPLS resources.

1. **Workspace lockdown:** restore Workspace A public access to `Allow` from a
  private/allowed client; verify recovery.
2. **Report/model:** disable refresh schedules, unbind the failed connection,
  and remove only newly created report/model items after owner approval.
3. **Pipeline/lakehouse:** stop triggers, preserve run logs, remove only the
  failed pipeline and destination artifacts created by the change.
4. **OPDG:** remove a failed member only after another cluster member is Online;
  retain the recovery key and connection ownership.
5. **Phase B:** run a fresh plan. Destroy/import only the private endpoint and
  hidden Private Link service owned by the Phase B state. Retain runner
  Workspace Admin until Terraform lifecycle work is complete.
6. **Workspaces:** remove only empty workspaces after confirming no items,
  connections, assignments, or audit-retention obligations remain.
7. **Phase A:** pause capacity for cost control before considering destroy.
  Destroy only after Phase B/workspaces are removed and shared DNS/peering
  ownership is confirmed.
8. **Layer 1/backend:** customer platform change only. Preserve state versions,
  logs, and backups according to retention policy.

Before any Terraform rollback:

```bash
terraform state list
terraform plan -destroy -var-file="$TFVARS_FILE" -out=rollback.tfplan
terraform show -no-color rollback.tfplan
```

Approval is required before applying a destroy plan.

## Troubleshooting matrix

| Symptom | Likely cause | Operator action |
|---|---|---|
| Backend `403` | Runner lacks Blob data-plane role, wrong identity, or network rules block it | Verify private DNS/TCP 443, then **Storage Blob Data Contributor** and token context; do not enable storage keys |
| Backend name resolves publicly | Private DNS record/link/forwarder missing | Stop; network/DNS owner fixes `privatelink.blob.core.windows.net` path |
| Phase A data source not found | `env`, `org`, or `subcode_connectivity`/`subcode_monitor` mismatch | Compare actual Layer 1 names with private tfvars; regenerate plan |
| Peering not Connected | Hub or on-prem/spoke peering missing, or forwarded traffic not allowed | Network owner corrects the VNet peering (both directions, allow forwarded traffic); the firewall is the transit |
| Phase B `409 Workspace validation failed` | Deployment identity is not Workspace A Admin, or tenant/workspace ID is wrong | Repeat Step 7 read-back, verify IDs, delete saved plan, replan |
| Private endpoint not Approved | Private Link service validation or Azure permissions failed | Inspect endpoint connection state and activity log; do not lock down |
| FQDN resolves publicly/NXDOMAIN | Incorrect workspace FQDN, DNS zone group, zone link, or on-prem forwarder | Reconstruct FQDN from workspace ID; compare PE NIC IPs and DNS records |
| TCP 443 fails after private DNS works | Route, NSG, Firewall/SWG, or return path blocks traffic | Use Network Watcher next hop and connection troubleshoot; network owner fixes path |
| Authenticated private API is `401/403` | Token audience, managed identity workspace role, or Fabric permission issue | Acquire token for `https://api.fabric.microsoft.com`; verify role assignment; never print token |
| Gateway network test fails | Missing Relay/Entra/Fabric FQDN or port; proxy/TLS issue | Open detailed port-test result, update approved egress, retry |
| Gateway is Offline | Windows service stopped, version unsupported, Relay blocked, or cluster registration issue | Check `PBIEgwService`, gateway logs/version, port test, and cluster member status |
| SQL connection test fails | DNS/route/firewall, SQL listener/TLS, or credential permission | Test from OPDG host, verify least privilege and certificate; do not broaden to sysadmin |
| Pipeline row counts differ | Source filter, mapping, conversion, or partial write | Preserve run logs, stop downstream use, correct mapping, rerun to a clean target |
| Semantic refresh unsupported/fails | Unsupported item/mode with restricted workspace or wrong gateway mapping | Return to architecture review; do not reopen Workspace A public access permanently |
| Public deny breaks private path | Lockdown was premature or private endpoint/DNS/client FQDN is wrong | Roll back to `Allow` from private client, diagnose, repeat Step 13 |

### Terraform state lock recovery

The AzureRM backend uses an Azure Blob lease. If Terraform reports a lock:

1. Confirm no operator, CI job, or background process is running Terraform.
2. Record the lock ID and owner from the error.
3. Use `terraform force-unlock <LOCK_ID>` only after ownership is confirmed and
  according to the customer's change process.
4. Do not break the storage blob lease manually unless Terraform cannot clear
  it and the storage owner approves the recovery.
5. Run `terraform plan` immediately after recovery and investigate drift.

## Evidence index

| Evidence | Location |
|---|---|
| Layer 1 screenshots and inventory | [platform/DEPLOYMENT.md](platform/DEPLOYMENT.md) |
| Fabric portal screenshots | `workloads/fabric/images/` |
| Fabric module architecture | [workloads/fabric/README.md](workloads/fabric/README.md) |
| Fabric reference-lab history and API evidence | [workloads/fabric/REFERENCE-LAB.md](workloads/fabric/REFERENCE-LAB.md) |
| Foundry deployment evidence | Not available; Layer 3 implementation gate is closed |
| Architecture diagrams | `docs/diagrams/` and `docs/images/` |
| Terraform validation | Run in each Terraform root before plan/apply |
| Secrets check | `bash scripts/check-sensitive.sh` |

## Firewall rule reference (OPDG + Fabric)

This is the complete, **tag-free** firewall rule set that lets the on-premises
data gateway (OPDG) and Microsoft Fabric operate through the hub Azure Firewall.
Every rule is an explicit **FQDN** or **IP/port** — no Azure service tags and no
FQDN tags — so the same set can be replicated on a customer on-premises firewall
that has no Azure tag support.

- Implemented as code: [platform/20-connectivity-hub/firewall-rules.tf](platform/20-connectivity-hub/firewall-rules.tf)
  (rule collection group `opdg-fabric` on the hub firewall policy).
- Standalone reference with discovery queries: [docs/fabric-opdg-firewall-rules.md](docs/fabric-opdg-firewall-rules.md)
- Sources: Microsoft OPDG communication settings and the Fabric allowlist URLs docs.

**Rule processing order** in Azure Firewall is DNAT → Network → Application (a
network match short-circuits application rules). Therefore only IP/private-link
flows live in the network collection; all HTTP/HTTPS/TDS flows are application
rules (Azure Firewall rejects wildcard FQDNs in network rules).

### Network rules — `opdg-network-allow` (priority 100, Allow)

Source for all rules: the on-premises address space (e.g. `172.16.0.0/16`).

| Rule | Destination | Ports | Purpose |
|---|---|---|---|
| `fabric-privatelink-443` | Fabric private-endpoint subnet (e.g. `10.2.0.0/27`) | TCP 443 | Fabric data-plane over Private Link |

### Application rules — `opdg-app-allow` (priority 200, Allow)

Source for all rules: the on-premises address space.

| Rule | FQDNs | Protocol/Port | Purpose |
|---|---|---|---|
| `gateway-auth` | `*.login.windows.net`, `login.live.com`, `aadcdn.msauth.net`, `login.microsoftonline.com`, `*.microsoftonline-p.com` | Https 443 | Entra ID / OAuth2 sign-in |
| `gateway-core` | `*.download.microsoft.com`, `*.powerbi.com`, `*.analysis.windows.net`, `*.servicebus.windows.net`, `*.dc.services.visualstudio.com`, `ecs.office.com`, `gatewayadminportal.azure.com` | Https 443 | Cluster discovery, installer, **Azure Relay/Service Bus**, telemetry, admin |
| `gateway-ncsi` | `*.msftncsi.com` | Http 80 | Internet connectivity test |
| `fabric-workload` | `*.core.windows.net`, `*.dfs.fabric.microsoft.com`, `*.frontend.clouddatahub.net` | Https 443 | OneLake writes, DFS, pipeline front-end |
| `fabric-platform` | `*.fabric.microsoft.com`, `*.onelake.dfs.fabric.microsoft.com`, `*.onelake.blob.fabric.microsoft.com`, `*.pbidedicated.windows.net` | Https 443 | Fabric portal + OneLake |
| `fabric-sql-tds` | `*.datawarehouse.fabric.microsoft.com`, `*.datawarehouse.pbidedicated.windows.net`, `*.datawarehouse.pbidedicated.microsoft.com`, `*.datamart.fabric.microsoft.com`, `*.datamart.pbidedicated.microsoft.com`, `*.pbidedicated.microsoft.com`, `*.pbidedicated.windows.net`, `*.database.fabric.microsoft.com`, `*.cloudapp.azure.com` | Mssql 1433 | Fabric DW / Datamart / staging lakehouse (TDS) |
| `certificate-revocation` | `oneocsp.microsoft.com`, `ocsp.digicert.com`, `crl3.digicert.com`, `crl4.digicert.com`, `cacerts.digicert.com`, `www.microsoft.com`, `crl.microsoft.com`, `ctldl.windowsupdate.com` | Http 80, Https 443 | CRL / OCSP checks (often missing from docs) |

### Management-plane rules — `management-plane` (priority 150, Allow)

Only required when the **management/runner** host egress is also forced through
the firewall (so Terraform/az keep working). Map these to the management path,
not the OPDG workload, in production.

| Rule | FQDNs | Protocol/Port | Purpose |
|---|---|---|---|
| `runner-arm-storage` | `management.azure.com`, `management.core.windows.net`, `*.blob.core.windows.net`, `login.microsoftonline.com`, `login.windows.net` | Https 443 | ARM control plane + storage data plane |

### Default deny (discovery instrument) — `opdg-deny-log` (priority 300, Deny)

| Rule | FQDNs | Protocol/Port | Purpose |
|---|---|---|---|
| `deny-all-web-log` | `*` | Http 80, Https 443 | Log every web FQDN not explicitly allowed; becomes the production default-deny |

### Validation notes

- **HTTPS-only mode confirmed.** The gateway app *Network ports test* connected
  to every Azure Relay server on **TCP 443 only** (no AMQP 5671-5672 / 9350-9354).
  With HTTPS mode enforced, the `gateway-core` `*.servicebus.windows.net` rule on
  443 is sufficient; the AMQP ports can be omitted. The ports test is the
  authoritative per-gateway, per-region endpoint list.
- **Confirmed by firewall logs.** With all OPDG egress routed through the hub
  firewall, `AZFWApplicationRule` showed `gateway-core` allowing
  `*.servicebus.windows.net` and `fabric-workload` allowing
  `*.frontend.clouddatahub.net` — a 76/76 ports-test pass through least-privilege
  wildcard rules, no IPs or tags.
- **Discovery:** remove any broad allow, run a gateway refresh, then read
  `AZFWApplicationRule`/`AZFWNetworkRule` `Deny` entries to surface endpoints the
  docs missed, and promote confirmed ones into the allow rules above.
- **No inbound internet ports** are required by the OPDG.
- OPDG↔SQL (TCP 1433) is on-premises-only and is **not** seen by the Azure
  firewall; validate that port on the gateway host itself.

## Appendix A: Cross-workspace semantic-model refresh into a private Workspace A

This appendix is the full procedure for keeping the public **Workspace B** report
refreshing after **Workspace A** is locked down in Phase 9. Phase 7 (Step 12) and
Phase 9 (Step 14) reference it.

### The problem (observed in this lab, 2026-07-20)

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

### Root cause (Microsoft-documented, by design)

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

### The supported fix: bind the model to a gateway with private access to A

Microsoft publishes two step-by-step walkthroughs for exactly this topology:

- VNet data gateway:
  https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-power-bi-virtual-network
- On-premises data gateway (OPDG):
  https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-on-premises-data-gateway

Because this lab already runs an OPDG (`azlab-gateway`) inside the private
network, the OPDG pattern applies.

#### Step 1 — Build the workspace-private connection string (mandatory)

The normal warehouse hostname you copy from the portal
(`<hash>.datawarehouse.fabric.microsoft.com`) **stops working** once Workspace A
is private. You must insert one extra label — **`z{xy}`** — into that hostname.
Read this even if you have never touched DNS before; it is just string surgery.

**What `z{xy}` means (the recipe):**

1. **`z`** is always the literal letter `z`. It never changes.
2. **`{xy}`** is the **first two characters of Workspace A's object ID, after you
   delete the dashes**.

**Worked example — Workspace A ID `a20cea33-31c4-4290-8cad-d67802ed67e8`:**

| Step | Do this | Result |
|---|---|---|
| 1 | Remove the dashes from the ID | `a20cea3331c4...` |
| 2 | Take the first **2** characters | **`a2`** |
| 3 | Put a `z` in front of those two characters | **`za2`** |

So for this workspace the label is **`za2`**.

**Where the label goes** — insert `.za2` between the hash and `datawarehouse`.
Everything else in the hostname stays **exactly** the same:

| Which name | Hostname |
|---|---|
| **Public** (fails when private) | `yzg45...af3lh5a.datawarehouse.fabric.microsoft.com` |
| **Private** (this is the one to use) | `yzg45...af3lh5a`**`.za2`**`.datawarehouse.fabric.microsoft.com` |

**What you actually type into the gateway connection:**

- **Server** = the **private** hostname above (the one that contains `.za2.`).
- **Database** = the lakehouse name (`lh_onprem_private`) or the lakehouse GUID.

> **Plain-English summary:** the public name is the blocked front door. Adding
> `z` + the workspace ID's first two characters is like writing the workspace's
> private apartment number on the envelope so the private link can deliver it.

> "You need to add `z{xy}` to the regular warehouse connection string ... This
> FQDN isn't available as part of the DNS configurations for the private
> endpoint."
> — [Workspace-level private links overview](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview#connecting-to-workspaces)

#### Step 2 — DNS for the datawarehouse FQDN (the gap in this lab)

The workspace private endpoint auto-registers these A records in
`privatelink.fabric.microsoft.com` (verified in this lab):

| Sub-resource | Private IP |
|---|---|
| `a20cea33...za2.w.api`   | 10.2.0.4 |
| `a20cea33...za2.c`       | 10.2.0.5 |
| `a20cea33...za2.onelake` | 10.2.0.6 |
| `a20cea33...za2.dfs`     | 10.2.0.7 |
| `a20cea33...za2.blob`    | 10.2.0.8 |

There is **no explicit `datawarehouse` A record** — but one is **not needed**.
The `za2` datawarehouse FQDN resolves through a CNAME chain to the `.c`
sub-resource, which already has a private A record in the zone:

```
yzg45...za2.datawarehouse.fabric.microsoft.com
  -> CNAME a20cea33...za2.c.fabric.microsoft.com
  -> CNAME a20cea33...za2.c.privatelink.fabric.microsoft.com
  -> A     10.2.0.5   (already registered by the workspace private endpoint)
```

Verified from the runner VM (inside the allowed VNet):
`getent hosts yzg45...za2.datawarehouse.fabric.microsoft.com` -> `10.2.0.5`.
So on this lab **no manual DNS record was required** — the existing workspace
private endpoint DNS is sufficient once the gateway uses the `za2` FQDN.

> **VERIFIED WORKING (2026-07-20):** created OPDG SQL connection
> `sql-fabric-private-za2` (server = `za2` datawarehouse FQDN, database
> `lh_onprem_private`, OAuth2). The **test connection passed** and a subsequent
> semantic-model refresh **Completed** with no `CrossWorkspaceRequestNotAllowed`.
> Evidence: `workloads/fabric/evidence/post-lockdown-refresh-FIXED-via-gateway.json`.

**Firewall note:** the hub firewall's existing `fabric-privatelink-443` network
rule (TCP 443 to `10.2.0.0/27`) was **sufficient** — the Fabric SQL analytics
endpoint tunnels over 443 to the `.c` private-endpoint IP. No 1433 rule was
needed.

#### Step 3 — Create the gateway SQL connection and bind the model

1. In **Manage connections and gateways**, select **+ New**, choose
   **On-premises**, and pick the OPDG cluster (`azlab-gateway`). Set
   **Connection type = SQL Server**:
   - Server: the `za2` datawarehouse FQDN (Step 1)
   - Database: `lh_onprem_private` (or the lakehouse GUID)
   - Authentication method: **OAuth 2.0** -> **Edit credentials** -> sign in

   ![New gateway SQL connection form](workloads/fabric/images/fix-02-sql-connection-za2-form.jpeg)

2. Leave **Skip test connection** unchecked and select **Create**. The test must
   pass (green check), confirming the gateway resolves the `za2` FQDN privately
   and reaches the SQL analytics endpoint over 443:

   ![Gateway connection created and tested](workloads/fabric/images/fix-05-connection-created.jpeg)

3. Bind the semantic model to this connection. Either in **Workspace B ->
   semantic model -> Settings -> Gateway and cloud connections** (toggle
   **Gateway connections** On, map the data source), or via the API:

   ```
   POST https://api.powerbi.com/v1.0/myorg/groups/{workspaceBId}/datasets/{modelId}/Default.BindToGateway
   { "gatewayObjectId": "<opdg-id>", "datasourceObjectIds": ["<connection-id>"] }
   ```

   > Tip: if the model still points at the public FQDN, first repoint its
   > datasource server to the `za2` FQDN via `Default.UpdateDatasources`, so it
   > matches the gateway connection's server string.

4. Trigger a refresh. `CrossWorkspaceRequestNotAllowed` should be gone; traffic
   now flows: model (B) -> gateway -> private endpoint -> Workspace A SQL
   analytics endpoint.

#### Do NOT use

- **OneLake catalog / Direct Lake** — Direct Lake is not yet supported against
  inbound-restricted workspaces. Use **Import** or **DirectQuery** against the
  SQL analytics endpoint (Import is what this lab uses).
- **Item/app sharing from Workspace A** — unsupported in restricted workspaces.

### End-to-end proof after lockdown (2026-07-20)

With Workspace A locked to private-only and the Workspace B model re-bound to the
OPDG (this fix), a brand-new on-prem row was pushed all the way to the public
report:

1. Inserted a 4th row on-prem: `(4, 'Northwind Traders', '2026-07-20', 1500.00)`
   -> source now 4 rows, total 5825.49.
2. **Copy job re-run (hop 1)** — triggered from the runner VM over the private
   `w.api` endpoint (`...za2.w.api...` -> 10.2.0.4); status **Completed**.
3. **Model refresh (hop 2)** through the gateway — **Completed**.
4. Public report now shows **4 rows incl. Northwind Traders** (screenshot
   `20-public-report-4th-row-after-lockdown.jpeg`).

#### Two operational gotchas observed

- **Management-plane isolation:** after lockdown, triggering the copy job from a
  public client (my laptop) — via both the Fabric REST API and the portal —
  is **denied** (`RequestDeniedByInboundPolicy` / page not found). Job control
  for the private workspace must originate **inside the allowed VNet** (the
  runner VM resolves `w.api` to the private endpoint 10.2.0.4 and succeeds), or
  via a **scheduled** run (which executes in the Fabric backend and is not
  subject to the client inbound check). This is why scheduling both hops is the
  practical customer pattern.
- **SQL analytics endpoint sync lag (the "two engines" problem):** immediately
  after the copy job wrote the Delta row, the first model refresh still returned
  3 rows; a second refresh a few minutes later returned all 4. This happens
  because two different engines are involved and they are **not** updated
  atomically:
  1. The **copy job** writes Parquet + `_delta_log` into the **OneLake** Delta
     table (the physical store) — this is immediate.
  2. The **SQL analytics endpoint** is an auto-generated, read-only T-SQL engine
     that sits *on top of* the lakehouse. It maintains its **own metadata** and
     **background-syncs** from the Delta log on a short delay (seconds to a few
     minutes). It is not the OneLake store itself.
  3. The public **Import semantic model** refreshes **through the SQL analytics
     endpoint** (we chose the "Azure SQL database" / SQL connector, not OneLake /
     Direct Lake). So a refresh that fires *before* the endpoint has synced reads
     the endpoint's stale metadata and loads the old row count — even though the
     OneLake Delta table already has the new row.

  Net effect: OneLake is fresh instantly, but the SQL analytics endpoint (and
  therefore the Import model) trails it. Budget a short delay — or an explicit
  endpoint metadata-refresh — between hop 1 (copy) and hop 2 (model refresh) when
  automating. Direct Lake would read OneLake directly and avoid this lag, but it
  is not yet supported against an inbound-restricted workspace, so the
  SQL-endpoint path with a small delay is the supported pattern here.

### Automating the pipeline (every N minutes)

Both hops can be scheduled so the public report stays current without manual
steps:

- **Hop 1 — Copy job schedule:** Copy job -> **Schedule** (min interval 15 min).
  For delta-only loads, create the job in **Incremental** mode with a watermark
  column (e.g. `OrderId` or a `ModifiedDate`); the current lab job is **Full
  copy** (re-copies all rows each run).
- **Hop 2 — Semantic model scheduled refresh:** model **Settings -> Refresh**.
  Import mode reloads the model each refresh; add an **incremental refresh**
  policy on the model for large tables. Schedule hop 2 a few minutes after hop 1
  to absorb the SQL-endpoint sync lag.

Scheduled runs execute in the Fabric backend, so they are **not** blocked by the
inbound policy that denies public-client job control.

### Operational implication for the customer

- New on-prem data always reaches **private Workspace A** (hop 1 via OPDG).
- The **public report refreshes only if hop 2 goes through a gateway** with
  private access to A (this fix). Without it, the public report is
  point-in-time as of the last pre-lockdown refresh.
- There is **no tenant admin toggle** that bypasses the access protector.

### References

- Cross-workspace communication — https://learn.microsoft.com/en-us/fabric/security/security-cross-workspace-communication
- Workspace-level private links overview — https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview
- Supported scenarios and limitations — https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-support
- VNet gateway walkthrough — https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-power-bi-virtual-network
- OPDG walkthrough — https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-on-premises-data-gateway
