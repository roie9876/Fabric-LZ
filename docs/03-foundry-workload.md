# 03 — Foundry workload (Layer 3)

A spoke for **Microsoft Foundry + Azure AI Search + Azure API Management**,
following the private-networking patterns proven in
[Azure-AI-Foundry-Networking](https://github.com/roie9876/Azure-AI-Foundry-Networking).

## Scope

- Foundry spoke VNet peered to the hub.
- BYO-VNet agent injection, private endpoints for Foundry / AI Search / Storage
  / Cosmos DB.
- Workspace-based Application Insights through the central Azure Monitor
  Private Link Scope; telemetry ingestion and operator queries use the hub
  AMPLS private endpoint. The Foundry stage reuses the central Azure Monitor
  private DNS zone IDs and links them to the Foundry spoke unless that spoke is
  configured to resolve through the hub DNS path.
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

The private Foundry foundation and private APIM are implemented,
reference-deployed, and validated with zero-drift Terraform plans. Hosted Agent
deployment and the APIM model/agent APIs and policies remain pending. The single
deployment lifecycle and evidence matrix are maintained in
[DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md#layer-3--foundry-workload).

## Dependencies

- `platform/20-connectivity-hub`, `platform/40-monitoring`,
  `workloads/foundry`, and `platform/35-ai-gateway`.

## Monitoring constraint

Application telemetry emitted by network-injected agent application code can
use OpenTelemetry and Application Insights through AMPLS. Microsoft currently
documents the native Foundry **Traces** experience as unsupported with a private
Application Insights resource, so native traces and trace-based evaluations are
not deployment pass criteria for the private-only workload.
