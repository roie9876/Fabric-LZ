# 03 — Foundry workload (Layer 3)

A spoke for **Microsoft Foundry + Azure AI Search + Azure API Management**,
following the private-networking patterns proven in
[Azure-AI-Foundry-Networking](https://github.com/roie9876/Azure-AI-Foundry-Networking).

## Scope

- Foundry spoke VNet peered to the hub.
- BYO-VNet agent injection, private endpoints for Foundry / AI Search / Storage
  / Cosmos DB.
- Workspace-based Application Insights associated with the central Azure Monitor
  Private Link Scope. Native Foundry traces use authenticated public ingestion
  and query because private-only Application Insights isn't supported for this
  feature; approved private clients continue to query through AMPLS.
- Publishing through the private **APIM** Standard v2 gateway in Stage 35.
- Forced egress through the hub Azure Firewall to the SWG.

## Implementation strategy

The deployed implementation:

1. Pins Microsoft Foundry Terraform Template 19 in
   `workloads/foundry/UPSTREAM_COMMIT`.
2. Adapts the template to consume the hub VNet, firewall private IP, central
   private DNS, Log Analytics workspace, and AMPLS.
3. Deploys APIM Standard v2 from the isolated `platform/35-ai-gateway` root.

## Status

The private Foundry foundation, Fabric IQ prompt agent, native tracing, and
private APIM are implemented and reference-deployed. The Foundry root is
validated with a zero-drift Terraform plan. Hosted Agent deployment and the APIM
model/agent APIs and policies remain pending. The single deployment lifecycle
and evidence matrix are maintained in
[DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md#layer-3--foundry-workload).

## Dependencies

- `platform/20-connectivity-hub`, `platform/40-monitoring`,
  `workloads/foundry`, and `platform/35-ai-gateway`.

## Monitoring design

Microsoft documents native Foundry **Traces** as unsupported with private-only
Application Insights. The applied reference therefore enables Application
Insights public ingestion/query and local authentication for the project's
`ApiKey` connection while retaining the AMPLS association. Foundry and Agent
Service remain private and deny by default. On 2026-07-26, a fresh prompt-agent
run appeared in the Traces blade and a private Log Analytics query returned
`AppEvents` and `AppDependencies`.
