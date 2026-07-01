# Azure Landing Zone — Fabric & Foundry Workloads

A vendor-neutral, **Hub & Spoke** Azure Landing Zone reference, built as three
independent layers so each can be developed and tested on its own:

1. **Platform (Landing Zone foundation)** — management groups, connectivity hub
   (Azure Virtual Network Manager, Azure Firewall, ExpressRoute, DDoS, Private
   DNS Resolver), secure egress, central monitoring, and security tooling.
2. **Fabric workload** — a spoke for Microsoft Fabric with private connectivity.
3. **Foundry workload** — a spoke for Microsoft Foundry + Azure AI Search + APIM
   (reuses the patterns from
   [Azure-AI-Foundry-Networking](https://github.com/roie9876/Azure-AI-Foundry-Networking)).

> This repository contains **only technology and architecture**. It carries no
> customer, partner, or environment identity. See
> [docs/PUBLISHING.md](docs/PUBLISHING.md) for how that separation is enforced.

## Design principles

- **Everything as code** — Terraform only; no manual production changes.
- **Hub & Spoke via Azure Virtual Network Manager** — connectivity, security
  admin rules, UDRs and NSGs managed centrally.
- **All east-west and on-prem traffic flows through Azure Firewall.**
- **Internet egress is forced through a 3rd-party Secure Web Gateway (SWG)** —
  the module is vendor-agnostic; the brand is configured privately.
- **North-south publishing through Azure API Management.**
- **Public IP protection with Azure DDoS.**
- **Defender for Cloud + a CNAPP layer** for posture and workload protection.

## Repository layout

```
platform/            Layer 1 — Landing Zone foundation (Terraform stages)
  00-bootstrap/        remote state, providers, CI identity
  10-management-groups/ mgmt / workloads / monitor / sandbox
  20-connectivity-hub/  hub VNet, AVNM, Firewall + policy, ER GW, DDoS, DNS resolver
  30-egress/            forced-tunnel egress to the SWG (vendor-agnostic)
  40-monitoring/        Log Analytics, AMPLS, alerts, DCR, workbooks
  50-security/          Defender for Cloud, CNAPP onboarding hooks
workloads/
  fabric/            Layer 2 — Fabric spoke + private links
  foundry/           Layer 3 — Foundry + AI Search + APIM spoke
modules/             reusable Terraform modules (naming, spoke-vnet, ...)
examples/
  lab/               small sandbox values (safe placeholders)
  enterprise/        the enterprise-shaped topology, fully tokenized
docs/                sanitized architecture and how-to
_private/            git-ignored real values (never published)
```

## Naming convention

Resources follow `azr-<env>-<org>-<subcode>-<type>-<role>`. The **scheme** is
public; the real `org` and `subcode` values live only in `_private/`. See
[docs/naming-convention.md](docs/naming-convention.md).

## Getting started (lab)

```bash
# 1. Install guardrails (blocks identity leaks before they are committed)
pipx install pre-commit && pre-commit install

# 2. Create your private overlay
cp _private/denylist.txt.example      _private/denylist.txt
cp _private/enterprise.tfvars.example _private/enterprise.private.tfvars
#   ...edit both with your real values...

# 3. Deploy a layer (example)
cp examples/lab/lab.tfvars.example examples/lab/lab.tfvars   # now git-ignored
cd platform/20-connectivity-hub
terraform init
terraform apply -var-file=../../examples/lab/lab.tfvars
```

## Layers & order

```
platform/00 → 10 → 20 → 30 → 40 → 50   (foundation, once)
        │
        ├── workloads/fabric            (Layer 2)
        └── workloads/foundry           (Layer 3)
```

## License

[MIT](LICENSE).
