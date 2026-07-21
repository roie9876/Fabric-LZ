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
- Publishing through the shared **APIM** platform in the connectivity layer.
- Forced egress through the hub Azure Firewall to the SWG.

## Reuse strategy

Rather than duplicate the Foundry Bicep/Terraform, this layer will:

1. Reference the upstream repo's Template-15-style private network setup, and
2. Adapt inputs to consume the hub VNet, firewall private IP, and private DNS
   zones produced by `platform/20-connectivity-hub`.

## Status

Architecture only; the Terraform release gate is closed. The single deployment
lifecycle and planned Layer 3 sequence are maintained in
[DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md#layer-3--foundry-workload). See
`workloads/foundry/` for the future Terraform entry point.

## Dependencies

- `platform/20-connectivity-hub`, `platform/30-egress`, `platform/40-monitoring`,
  and the APIM platform.

## Monitoring constraint

Application telemetry emitted by network-injected agent application code can
use OpenTelemetry and Application Insights through AMPLS. Microsoft currently
documents the native Foundry **Traces** experience as unsupported with a private
Application Insights resource, so native traces and trace-based evaluations are
not deployment pass criteria for the private-only workload.
