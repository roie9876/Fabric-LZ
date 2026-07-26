# Workload — Private Foundry Standard Agent (Layer 3)

Terraform adaptation of Microsoft Foundry sample
[`19-private-network-agent-setup-with-tools`](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/19-private-network-agent-setup-with-tools),
pinned by [`UPSTREAM_COMMIT`](UPSTREAM_COMMIT).

The root deploys a Sweden Central Standard Agent environment with BYO resources,
customer-managed networking, private endpoints, central DNS, and private Azure
Monitor integration. The authoritative execution sequence and screenshots live
in [DEPLOYMENT-GUIDE.md](../../DEPLOYMENT-GUIDE.md#layer-3--foundry-workload).

## Landing-zone adaptations

The upstream sample is extended to:

- Use deterministic landing-zone naming and the existing private backend.
- Deploy the Foundry spoke at `10.3.0.0/16` in Sweden Central.
- Globally peer the spoke to the Israel Central hub and route agent/tool egress
  through Azure Firewall `10.0.0.4`.
- Create Azure AI Search Standard with two replicas, one partition, semantic
  search, Entra-only authentication, and public access disabled.
- Deploy gpt-5-mini `2025-08-07` as GlobalStandard capacity 40.
- Create private ZRS Storage, Cosmos DB, and Premium ACR for Hosted Agent images.
- Create both mandatory capability hosts. The pinned upstream Terraform omitted
  the account host even though its README promised both.
- Centralize Foundry/Search/Cosmos/ACR DNS zones in the hub and reuse the
  existing authoritative Blob zone.
- Create workspace-based Application Insights with public ingestion/query and
  local authentication enabled for native Foundry Traces, attach it to the
  central LAW/AMPLS, and link the Azure Monitor zones to the Foundry spoke.

Microsoft does not support native Foundry server-side traces with private-only
Application Insights. The public Application Insights access is a deliberate
compatibility exception; Foundry and Agent Service remain private and
deny-by-default. Approved private clients continue to query through AMPLS.

## Resources

- Foundry spoke with agent, private-endpoint, and tools subnets.
- Agent/tools subnet delegation to `Microsoft.App/environments`.
- Hub peerings and forced-egress route table.
- Foundry account/project, model deployment, connections, RBAC, and account +
  project capability hosts.
- BYO Storage, Cosmos DB, Search Standard, and private ACR.
- Private endpoints and central DNS links.
- Hybrid-access Application Insights and AMPLS scoped-resource association.

The Hosted Agent version is an application release and is deployed through
`azd ai agent`, not Terraform. APIM is owned by `platform/35-ai-gateway`.

## Deploy

Run from the private Terraform runner after Layer 1 is healthy:

```bash
cd /home/azureuser/lz/workloads/foundry
export ARM_USE_MSI=true
export FOUNDRY_BACKEND_FILE=../../_private/backend.hcl
export FOUNDRY_TFVARS_FILE=../../_private/foundry.private.tfvars
terraform init -reconfigure -backend-config="$FOUNDRY_BACKEND_FILE"
terraform validate
terraform plan -var-file="$FOUNDRY_TFVARS_FILE" -out=foundry.tfplan
terraform show -no-color foundry.tfplan
terraform apply foundry.tfplan
terraform plan -detailed-exitcode -var-file="$FOUNDRY_TFVARS_FILE"
```

Layer 3 uses the existing private backend with its isolated state key and a
dedicated Foundry tfvars file. The broader lab overlay is not passed to this
root, and operator UPNs are not part of Foundry infrastructure configuration.

Terraform `>= 1.10` is required. The reference runner uses `1.13.5`.

## Acceptance gates

- The target workload subscription has sufficient Search quota for the approved
  tier. Standard Agent setup does not require S3.
- All private endpoints Approved/Succeeded.
- Public network access and local keys disabled on Foundry, Search, Storage,
  Cosmos DB, and ACR. Application Insights public ingestion/query and local
  authentication are the documented exception required for native Traces.
- Both capability hosts Succeeded with the three expected BYO connection names.
- Search reports `standard`, two replicas, one partition.
- Foundry/Storage/Search/Cosmos/ACR/Monitor FQDNs resolve privately from the
  Foundry network and approved runner path.
- Agent/tools subnet next hop is the hub firewall; approved outbound flows pass.
- A fresh prompt-agent run appears in Foundry Traces and in the linked workspace
  without exposing prompt or response content in validation evidence.
- Final Terraform detailed exit code is `0`.

The hub firewall uses the tested explicit-FQDN baseline from
[Azure-AI-Foundry-Networking](https://github.com/roie9876/Azure-AI-Foundry-Networking#firewall-rules-reference):
MCR runtime images, Entra/managed identity, AzureML evaluation discovery,
`*.dataproxy.swedencentral.api.azureml.ms`, evaluation Blob assets, and
Application Insights SDK configuration. Optional SharePoint and fine-tuning
groups remain disabled until those features are approved.
