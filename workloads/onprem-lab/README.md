# Simulated On-Premises SQL and OPDG Lab

This Terraform root is an optional **sandbox-only** dependency for the Fabric
runbook. It creates two private Windows VMs inside an existing simulated
on-premises VNet:

- SQL Server 2022 Developer VM.
- On-premises Data Gateway (OPDG) staging VM.

Do not use this root as a production SQL Server or production gateway design.
Production requires customer-owned SQL operations, TLS, backup, HA/DR, at least
two supported OPDG hosts, approved secret management, monitoring, patching, and
capacity testing.

## Prerequisites

The root does not create the surrounding on-premises simulation. Before plan,
the following must already exist:

- Resource group, VNet, and workload subnet named by the input variables.
- Non-overlapping static addresses for SQL and OPDG.
- Outbound connectivity for Windows/PowerShell/gateway downloads and OPDG cloud
  dependencies.
- Hybrid route and DNS path to the Fabric workspace Private Endpoint.
- Private Terraform backend and runner with managed identity access.

## Resources

A fresh reference deployment creates 14 resources:

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
- Post-apply Terraform plan returns exit code `0`.

Continue with Step 10 of [../../DEPLOYMENT-GUIDE.md](../../DEPLOYMENT-GUIDE.md)
for interactive gateway installation and registration.
