# Simulated On-Premises SQL and OPDG Lab

This Terraform root is an optional **sandbox-only** dependency for the Fabric
runbook. It connects an existing simulated on-premises VNet to the hub and
creates two private Windows VMs in its workload subnet:

- SQL Server 2022 Developer VM.
- On-premises Data Gateway (OPDG) staging VM.

Do not use this root as a production SQL Server or production gateway design.
Production requires customer-owned SQL operations, TLS, backup, HA/DR, at least
two supported OPDG hosts, approved secret management, monitoring, patching, and
capacity testing.

## Prerequisites

The root does not create the surrounding on-premises VNet, NAT/Bastion services,
or private runner. Before plan, the following must already exist:

- Resource group, VNet, and workload subnet named by the input variables.
- Layer 1 hub VNet and Azure Firewall.
- Non-overlapping static addresses for SQL and OPDG.
- Outbound connectivity for Windows/PowerShell/gateway downloads and OPDG cloud
  dependencies.
- DNS forwarding to the hub Private DNS Resolver.
- Private Terraform backend and runner with managed identity access.

## Resources

A fresh reference deployment creates 20 resources:

- Direct `onprem-to-hub` and `hub-to-onprem` VNet peerings with forwarded
  traffic enabled and no gateway transit.
- Workload route table with `0.0.0.0/0` and the Fabric spoke prefix routed to
  the hub Azure Firewall, plus the workload-subnet association.

- Two NIC NSGs and two NIC-to-NSG associations.
- Two NICs with static private IPs.
- SQL Server Developer Windows VM and OPDG Windows VM.
- Random Windows administrator and SQL gateway-login passwords stored only in
  Terraform state.
- SQL host Custom Script Extension.
- SQL database Managed Run Command and its revision tracker.
- OPDG staging Custom Script Extension.

The SQL bootstrap configures TCP 1433, mixed authentication, database
`FabricHybridLab`, read-only login `fabric_gateway`, table
`dbo.SalesOrders`, and three sample rows. The OPDG bootstrap stages PowerShell
7.4, the DataGateway module, and Microsoft's standard-mode installer at
`C:\Installers\GatewayInstall.exe`.

Terraform does not perform the organizational sign-in, recovery-key entry, or
OPDG tenant registration.

### Existing lab adoption (2026-07-21)

The reference lab originally created its replacement peering and UDR manually
after removing the unsuccessful S2S VPN simulation. The two peerings, route
table, two routes, and subnet association were imported into this root without
recreation. The only applied change added the standard Terraform tags to the
route table. The empty VPN-era `GatewaySubnet` was then deleted after confirming
that no landing-zone virtual-network gateway, local-network gateway, connection,
or subnet IP configuration depended on it. The final detailed-exit-code plan
returned `0` (**No changes**).

## Deploy

Run from the private Terraform runner:

```bash
cd /home/azureuser/lz/workloads/onprem-lab
export ARM_USE_MSI=true
export ARM_SUBSCRIPTION_ID=<workloads-subscription-guid>
export ARM_TENANT_ID=<tenant-guid>
export TFVARS_FILE=../../_private/customer.private.tfvars
export BACKEND_FILE=../../_private/backend.hcl

terraform init -reconfigure -backend-config="$BACKEND_FILE"
terraform validate
terraform plan -var-file="$TFVARS_FILE" -out=onprem-lab.tfplan
terraform show -no-color onprem-lab.tfplan
# Review and approval happen here.
terraform apply onprem-lab.tfplan
terraform plan -detailed-exitcode -var-file="$TFVARS_FILE"
```

The final plan must return exit code `0`.

## Outputs and secret handling

Non-secret outputs provide VM names/IPs, SQL database/login names, and whether
manual gateway registration is required. `sql_gateway_password` is sensitive.

For production, provision SQL credentials through the customer's approved
secret manager instead of Terraform state. In the sandbox, retrieve the value
only from an approved interactive session on the private runner immediately
before entering it into the Fabric connection dialog. Do not retrieve it through
Azure VM Run Command, CI logs, chat, screenshots, shell tracing, or shared
terminal recordings. Rotate the lab credential if exposure is suspected.

## Validation

- Both VMs and bootstrap extensions report `Succeeded`.
- Managed SQL command reports exit code `0` and validates three rows using the
  generated SQL login.
- SQL listens on TCP 1433 and only the OPDG address is allowed by the dedicated
  NSG/Windows Firewall rule.
- `C:\FabricHybridLab.ready` contains `SQL_READY`.
- `C:\FabricGatewayInstaller.ready` and
  `C:\Installers\GatewayInstall.exe` exist.
- OPDG reaches SQL and all five private Fabric workspace endpoints.
- Both on-prem/hub peerings are `Connected` / `FullyInSync` with forwarded
  traffic enabled.
- The workload subnet routes `0.0.0.0/0` and the Fabric spoke prefix through
  the hub firewall private IP.
- Post-apply Terraform plan returns exit code `0`.

Continue with Step 10 of [../../DEPLOYMENT-GUIDE.md](../../DEPLOYMENT-GUIDE.md)
for interactive gateway installation and registration.
