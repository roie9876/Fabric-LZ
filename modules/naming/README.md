# `modules/naming`

Produces resource names following the LZ convention
`azr-<env>-<org>-<subcode>-<type>-<role>` and fails the plan if a name violates
the approved regex.

## Usage

```hcl
module "fw_rg_name" {
  source  = "../../modules/naming"
  env     = var.env
  org     = var.org
  subcode = var.subcode_connectivity
  type    = "rg"
  role    = "fw-hub"
}

resource "azurerm_resource_group" "fw" {
  name     = module.fw_rg_name.name   # azr-prd-org-0000-rg-fw-hub
  location = var.location
}
```

## Inputs

| Name | Description | Default |
|---|---|---|
| `env` | Environment token (`prd`/`npr`/`dev`/`tst`/`sbx`) | — |
| `org` | Organization prefix (real value supplied privately) | `org` |
| `subcode` | Subscription short-code | `0000` |
| `type` | Resource type token | — |
| `role` | Purpose token | — |

## Output

| Name | Description |
|---|---|
| `name` | The fully-formed, regex-validated resource name |
