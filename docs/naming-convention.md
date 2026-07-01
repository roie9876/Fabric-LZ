# Naming convention

Resources follow a fixed scheme. The **scheme is public**; the real values for
`org` and `subcode` live only in `_private/` and are supplied as Terraform
variables.

## Resource name pattern

```
azr-<env>-<org>-<subcode>-<type>-<role>
```

| Token | Meaning | Public placeholder | Real value lives in |
|---|---|---|---|
| `env` | environment | `prd`, `npr`, `sbx` | public (not sensitive) |
| `org` | organization prefix | `org` | `_private/*.private.tfvars` |
| `subcode` | subscription short-code | `0000` | `_private/*.private.tfvars` |
| `type` | resource type | `rg`, `vnet`, `fw`, `pe` | public |
| `role` | purpose | `hub`, `apim`, `monitor` | public |

## Examples (tokenized)

| Real-world purpose | Tokenized name |
|---|---|
| Firewall hub RG | `azr-prd-org-0000-rg-fw-hub` |
| Hub core VNet | `azr-prd-org-0000-vnet-hub-core` |
| DNS hub RG | `azr-prd-org-0000-rg-dns-hub` |
| Egress hub RG | `azr-prd-org-0000-rg-egress-hub` |
| APIM network RG | `azr-prd-org-0000-rg-apim-network` |
| Monitor network RG | `azr-prd-org-0000-rg-monitor-network` |

## Enforcement

- All names are produced by the [`modules/naming`](../modules/naming) module —
  never hand-typed.
- CI validates names against a regex before `terraform apply`, matching the
  design mandate that *every* Resource Group is created only through the naming
  module with a naming-regex check.
