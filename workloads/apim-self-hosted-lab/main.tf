data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Developer classic is intentionally isolated from the StandardV2 Foundry AI
# Gateway. It is a paid, nonproduction control plane with no production SLA.
resource "azurerm_api_management" "lab" {
  name                = var.api_management_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.lab.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "Developer_1"

  # The off-network self-hosted gateway must reach the public configuration
  # endpoint. This exception applies only to this disposable lab APIM instance.
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# AzureRM doesn't expose this child consistently, so AzAPI uses the stable ARM
# gateway contract. Runtime credentials are generated after apply and never
# written to Terraform state or Git.
resource "azapi_resource" "runner_gateway" {
  type      = "Microsoft.ApiManagement/service/gateways@2022-08-01"
  name      = var.gateway_name
  parent_id = azurerm_api_management.lab.id

  body = {
    properties = {
      description = "Self-hosted gateway on the simulated on-premises Terraform runner"
      locationData = {
        name            = "simulated-on-premises"
        city            = "Private runner"
        district        = "Lab"
        countryOrRegion = "Israel"
      }
    }
  }
}

resource "azurerm_api_management_api" "runner_echo" {
  name                  = "runner-echo"
  resource_group_name   = data.azurerm_resource_group.lab.name
  api_management_name   = azurerm_api_management.lab.name
  revision              = "1"
  display_name          = "Runner echo validation API"
  path                  = "runner-echo"
  protocols             = ["http"]
  service_url           = "http://apim-shgw-echo:8080"
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "runner_echo_get" {
  operation_id        = "get-runner-echo"
  api_name            = azurerm_api_management_api.runner_echo.name
  api_management_name = azurerm_api_management.lab.name
  resource_group_name = data.azurerm_resource_group.lab.name
  display_name        = "Get runner echo"
  method              = "GET"
  url_template        = "/"

  response {
    status_code = 200
  }
}

# An API must be explicitly associated with a self-hosted gateway. Without this
# child association, the runner gateway returns 404 even though the API exists.
resource "azapi_resource_action" "runner_gateway_echo_api" {
  type        = "Microsoft.ApiManagement/service/gateways/apis@2022-08-01"
  resource_id = "${azapi_resource.runner_gateway.id}/apis/${azurerm_api_management_api.runner_echo.name}"
  method      = "PUT"
  when        = "apply"

  body = {
    properties = {}
  }
}

resource "azapi_resource_action" "runner_gateway_echo_api_cleanup" {
  type        = "Microsoft.ApiManagement/service/gateways/apis@2022-08-01"
  resource_id = "${azapi_resource.runner_gateway.id}/apis/${azurerm_api_management_api.runner_echo.name}"
  method      = "DELETE"
  when        = "destroy"

  depends_on = [azapi_resource_action.runner_gateway_echo_api]
}