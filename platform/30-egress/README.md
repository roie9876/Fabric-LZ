# Stage 30 — Secure Egress

Forces internet egress through a 3rd-party **Secure Web Gateway (SWG)**. The
module is vendor-agnostic — it takes the NVA private IP (and optional FQDN
allow-lists) as input; the brand and appliance configuration stay in
`_private/`.

Design intent (from the LZ mandate): direct outbound internet from spokes is
blocked by NSG/UDR/Policy; the only egress path is Spoke → Azure Firewall → SWG
→ Internet.
