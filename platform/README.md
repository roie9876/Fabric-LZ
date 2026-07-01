# Platform — Layer 1 (Landing Zone foundation)

This layer builds the shared foundation that every workload (Fabric, Foundry)
depends on. It follows a **Hub & Spoke** design: one central connectivity hub
that owns network inspection, DNS, hybrid connectivity and egress, plus isolated
spokes for each workload.

Everything here is Terraform, deployed in stage order, and driven by tokens so
the public repo never reveals a real environment. Real values live in
[`_private/`](../_private/README.md).

---

## 1. Governance — management groups & policy

We use the **CAF Azure Landing Zone (ALZ) engine** (`avm-ptn-alz`) to stamp out
the management-group tree and a **minimal policy baseline**, but with a **custom
4-group hierarchy** that mirrors the target design rather than CAF's canonical
tree.

![Management group governance](../docs/images/01-governance.png)

- `mgmt` — platform: connectivity + management subscriptions
- `workloads` — Fabric + Foundry subscriptions
- `monitor` — centralized observability subscription
- `sandbox` — experimentation, isolated

The **minimal policy baseline** keeps the public reference approachable: enable
Microsoft Defender for Cloud, deny public IPs on spoke NICs, require TLS 1.2 /
HTTPS, and restrict allowed locations. It is designed to grow — add CAF policy
sets incrementally.

---

## 2. Network topology — Hub & Spoke

A single **Connectivity Hub VNet** owns the shared network services. Each
workload gets its own **spoke VNet**, peered to the hub. There is **no direct
spoke-to-spoke peering** — all inter-spoke and on-prem traffic is forced through
the hub **Azure Firewall** by a User-Defined Route (`0.0.0.0/0 → Firewall`).

![Hub and spoke topology](../docs/images/02-hub-spoke.png)

**Hub contents**
- **Azure Firewall + Policy** — the single inspection point for east-west and
  hybrid traffic.
- **ExpressRoute Gateway** — hybrid connectivity to on-premises (BGP).
- **DDoS Protection Plan** — protects hub public IPs.
- **Private DNS Resolver** (inbound + outbound) — hybrid name resolution.
- **Egress subnet** — hosts the Secure Web Gateway NVA (see §5).

**Spokes**
- **Fabric spoke** — Microsoft Fabric workload + forced-tunnel route table.
- **Foundry spoke** — Foundry + AI Search, published via **API Management** +
  forced-tunnel route table.

**Enforced traffic flows**

| Flow | Path | Control |
|---|---|---|
| Spoke → Spoke | Spoke A → Firewall → Spoke B | forced UDR + FW policy |
| Spoke → On-Prem | Spoke → Firewall → ER Gateway → On-Prem | FW policy + BGP |
| On-Prem → Spoke | On-Prem → ER Gateway → Firewall → Spoke | FW policy |
| Spoke → Internet | Spoke → Firewall → **SWG/Zscaler** → Internet | UDR + NSG deny direct egress |

---

## 3. Design decisions (and why)

| Decision | Choice | Rationale |
|---|---|---|
| Governance engine | CAF ALZ accelerator (`avm-ptn-alz`) | Inherit Microsoft's mgmt-group + policy machinery instead of hand-rolling it |
| MG hierarchy | Custom `mgmt / workloads / monitor / sandbox` | Mirror the target design faithfully |
| Policy baseline | Minimal (Defender + a few deny rules) | Keep the public reference approachable; grow later |
| Connectivity | **Classic hub-spoke peering + UDR** (no AVNM) | Simpler and more teachable for a public repo; see deviation note below |
| Log Analytics / Defender | Owned by our `40-monitoring` / `50-security` stages | Matches a dedicated **monitor** subscription; keeps layers separable |
| Egress | Vendor-agnostic **SWG NVA** abstraction | Works for Zscaler, a 3rd-party firewall, or a lab proxy — one swap point |
| CI | **GitHub Actions** (public); GitLab CI kept private | Public-friendly; the real pipeline stays out of the public repo |

> **Deviation — AVNM.** The reference target mandates **Azure Virtual Network
> Manager** for connectivity and security-admin rules. This public reference
> intentionally uses **classic peering + UDR** for clarity. Swap in AVNM for
> production once the topology is validated. This is a deliberate simplification,
> not an omission.

---

## 4. Deployment stages

Each stage is an independent Terraform root (isolated state), deployed once, in
order. Workloads consume the platform outputs afterwards.

![Deployment stages](../docs/images/04-stages.png)

```
00-bootstrap → 10-alz-governance → 20-connectivity-hub → 30-egress → 40-monitoring → 50-security
```

| Stage | Folder | Creates |
|---|---|---|
| 00 | `00-bootstrap` | Remote state backend, providers, CI (OIDC) identity |
| 10 | `10-alz-governance` | ALZ engine: MG tree + minimal policy + Defender |
| 20 | `20-connectivity-hub` | Hub VNet, Firewall + Policy, DDoS, DNS Resolver, ER GW |
| 30 | `30-egress` | Forced-tunnel egress to the SWG NVA (vendor-agnostic) |
| 40 | `40-monitoring` | Log Analytics, AMPLS, DCR, alerts, workbooks |
| 50 | `50-security` | Defender for Cloud plans + CNAPP onboarding |

---

## 5. Egress — Zscaler in production, a proxy stand-in in the lab

The target requires that **all internet-bound traffic from every spoke** is sent
to **Zscaler** (a third-party Secure Web Gateway) for inspection and policy —
never straight out to the internet. In Azure this is realized as an **NVA in the
hub egress subnet**, with spoke default routes pointing at it.

The key architectural insight: the landing zone's contract is just

> **spoke UDR `0.0.0.0/0` → Azure Firewall → a single "egress NVA private IP"**

Whatever sits at that IP — Zscaler Cloud Connector or a self-hosted proxy — is a
**swap point**. That means you can build and validate the whole LZ **without a
Zscaler license**, then swap the box in production.

![Forced egress: production vs. lab mimic](../docs/images/03-egress.png)

### How to mimic Zscaler in your own environment (no license)

Three fidelity levels — pick based on what you're testing:

**Level 1 — Azure Firewall only (cheapest).**
Use Azure Firewall's own FQDN filtering + logging as the "cloud proxy" stand-in.
No extra VM. Good for validating routing and *deny-all-then-allow* egress
policy. Limitation: there's no separate proxy hop, so the topology isn't a
faithful `FW → proxy → internet` chain.

**Level 2 — Self-hosted proxy VM (recommended).**
Deploy a small Ubuntu VM running **Squid** in the hub egress subnet. It plays the
exact role of the Zscaler Cloud Connector: spokes route `0.0.0.0/0 → Firewall →
Squid VM → internet`. You get URL filtering + access logs, so you can prove
"all egress is proxied and logged" just like Zscaler. Swapping to real Zscaler
later is a one-line change: point `egress_nva_private_ip` at the Zscaler Cloud
Connector's internal load balancer instead of the Squid VM.

Minimal Squid stand-in (lab only):

```bash
# On an Ubuntu VM in the hub EgressSwgSubnet:
sudo apt-get update && sudo apt-get install -y squid
# Enable IP forwarding so it can route spoke traffic to the internet
sudo sysctl -w net.ipv4.ip_forward=1
# NAT egress to the internet (mimics the Cloud Connector's outbound)
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# (Optional) transparent intercept of 80/443, or run as an explicit proxy on 3128
# Add allow/deny ACLs in /etc/squid/squid.conf to mimic Zscaler URL policy
```

Then set the platform variable so spokes route to it:

```hcl
# _private/enterprise.private.tfvars  (lab)
egress_nva_private_ip = "10.0.0.4"   # the Squid VM's NIC in the egress subnet
```

The `30-egress` stage already consumes `egress_nva_private_ip`, and the
`modules/udr` module writes `0.0.0.0/0 → <that IP>` onto spoke subnets — so no
code changes are needed to switch between the lab proxy and real Zscaler.

**Level 3 — Simulate the tunnel (highest fidelity).**
If you specifically want to test the *tunnel* behavior Zscaler uses (IPsec/GRE
forwarding to ZIA), run **strongSwan** on the proxy VM and terminate an IPsec
tunnel from the Azure VPN Gateway or firewall. This is rarely needed for
landing-zone routing tests and adds real complexity — use it only if the tunnel
itself is what you're validating.

### Recommendation for your test environment

Start at **Level 2 (Squid)**. It reproduces the production topology (`spoke →
FW → proxy → internet`), proves the forced-tunnel and logging behavior, costs
one small VM, and swaps cleanly to Zscaler in production by changing a single IP.

> A `modules/egress-proxy-lab` (Squid VM) can be scaffolded as the Level-2
> stand-in — clearly marked **lab only, never for production**. Ask and I'll add
> it.

---

## Regenerating the diagrams

Diagram sources are in [`docs/diagrams/`](../docs/diagrams) (`.drawio`, Azure2
icons). PNGs are exported to [`docs/images/`](../docs/images):

```bash
./scripts/render-diagrams.sh      # needs draw.io desktop installed
```
