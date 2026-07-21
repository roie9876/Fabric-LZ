# Workload — Foundry + AI Search + APIM (Layer 3)

Spoke for **Microsoft Foundry**, **Azure AI Search**, and publishing via
**Azure API Management**, reusing the private-networking patterns from
[Azure-AI-Foundry-Networking](https://github.com/roie9876/Azure-AI-Foundry-Networking).

## Build order

Requires Layer 1: `platform/20-connectivity-hub`, `platform/30-egress`,
`platform/40-monitoring`, and the APIM platform.

The authoritative end-to-end sequence is
[DEPLOYMENT-GUIDE.md](../../DEPLOYMENT-GUIDE.md#layer-3--foundry-workload). Do
not add a separate executable runbook here; release exact Foundry commands and
evidence into that Layer 3 section when this root is implemented.

## Reuse strategy

- Consume hub outputs: `hub_vnet_id`, `firewall_private_ip`, private DNS zones.
- Adapt the upstream Template-15-style BYO-VNet Foundry deployment to inject the
  agent subnet + private endpoints into this spoke.
- Publish agent/tool APIs through the shared APIM.

> **Release gate closed:** Terraform must be added and validated before this
> folder is deployable. See
> [docs/03-foundry-workload.md](../../docs/03-foundry-workload.md) for the target
> architecture and the unified guide for the deployment gate.
