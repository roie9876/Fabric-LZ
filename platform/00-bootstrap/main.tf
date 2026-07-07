##
# Stage 00 — Bootstrap
#
# Creates the Terraform remote-state storage account and a resource group to
# host it. This is the only stage that may use a local backend on first run;
# after the state storage exists, migrate this and all other stages to the
# azurerm backend via `-backend-config=../../_private/backend.hcl`.
#
# NOTE: skeleton starter. Extend with CI OIDC federated identity credentials
# (GitHub Actions) as needed.
##

module "state_rg_name" {
  source  = "../../modules/naming"
  env     = var.env
  org     = var.org
  subcode = var.subcode_management
  type    = "rg"
  role    = "tfstate"
}

resource "azurerm_resource_group" "state" {
  name     = module.state_rg_name.name
  location = var.location
  tags = {
    layer   = "platform"
    stage   = "00-bootstrap"
    managed = "terraform"
  }
}

# Storage account name has a 24-char lowercase-alnum limit; derive from tokens.
resource "azurerm_storage_account" "state" {
  name                            = substr(replace("azr${var.org}${var.subcode_management}tfstate", "-", ""), 0, 24)
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true
  }

  tags = {
    layer   = "platform"
    stage   = "00-bootstrap"
    purpose = "terraform-state"
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}
