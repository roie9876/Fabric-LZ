# 03 — Foundry workload (Layer 3)

A spoke for **Microsoft Foundry + Azure AI Search + Azure API Management**,
following the private-networking patterns proven in
[Azure-AI-Foundry-Networking](https://github.com/roie9876/Azure-AI-Foundry-Networking).

## Scope

- Foundry spoke VNet peered to the hub.
- BYO-VNet agent injection, private endpoints for Foundry / AI Search / Storage
  / Cosmos DB.
- Publishing through the shared **APIM** platform in the connectivity layer.
- Forced egress through the hub Azure Firewall to the SWG.

## Reuse strategy

Rather than duplicate the Foundry Bicep/Terraform, this layer will:

1. Reference the upstream repo's Template-15-style private network setup, and
2. Adapt inputs to consume the hub VNet, firewall private IP, and private DNS
   zones produced by `platform/20-connectivity-hub`.

## Status

Skeleton only. See `workloads/foundry/` for the Terraform entry point.

## Dependencies

- `platform/20-connectivity-hub`, `platform/30-egress`, `platform/40-monitoring`,
  and the APIM platform.
