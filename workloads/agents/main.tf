data "azurerm_resource_group" "foundry" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "foundry" {
  name                = var.foundry_vnet_name
  resource_group_name = data.azurerm_resource_group.foundry.name
}

data "azurerm_subnet" "container_apps" {
  name                 = var.container_apps_subnet_name
  virtual_network_name = data.azurerm_virtual_network.foundry.name
  resource_group_name  = data.azurerm_resource_group.foundry.name
}

data "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  resource_group_name = var.hub_resource_group_name
}

data "azurerm_container_registry" "agents" {
  name                = var.container_registry_name
  resource_group_name = data.azurerm_resource_group.foundry.name
}

data "azurerm_application_insights" "foundry" {
  name                = var.application_insights_name
  resource_group_name = data.azurerm_resource_group.foundry.name
}

data "azurerm_log_analytics_workspace" "central" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.log_analytics_resource_group_name
}

data "azurerm_api_management" "ai_gateway" {
  name                = var.api_management_name
  resource_group_name = data.azurerm_resource_group.foundry.name
}

locals {
  prefix             = "azr-sbx-lab-0001"
  foundry_account_id = "${data.azurerm_resource_group.foundry.id}/providers/Microsoft.CognitiveServices/accounts/${var.foundry_account_name}"
  apim_logger_id     = "${data.azurerm_api_management.ai_gateway.id}/loggers/foundry-application-insights"
}

resource "azurerm_container_app_environment" "agents" {
  name                               = "${local.prefix}-cae-agents"
  location                           = var.location
  resource_group_name                = data.azurerm_resource_group.foundry.name
  infrastructure_subnet_id           = data.azurerm_subnet.container_apps.id
  internal_load_balancer_enabled     = true
  log_analytics_workspace_id         = data.azurerm_log_analytics_workspace.central.id
  zone_redundancy_enabled            = false
  infrastructure_resource_group_name = "${local.prefix}-rg-cae-agents-infra"
  tags                               = var.tags

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 10
  }
}

resource "azurerm_private_dns_zone" "container_apps" {
  name                = azurerm_container_app_environment.agents.default_domain
  resource_group_name = data.azurerm_resource_group.foundry.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "container_apps_foundry" {
  name                  = "foundry-spoke-link"
  resource_group_name   = data.azurerm_resource_group.foundry.name
  private_dns_zone_name = azurerm_private_dns_zone.container_apps.name
  virtual_network_id    = data.azurerm_virtual_network.foundry.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "container_apps_hub" {
  name                  = "hub-link"
  resource_group_name   = data.azurerm_resource_group.foundry.name
  private_dns_zone_name = azurerm_private_dns_zone.container_apps.name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_a_record" "container_apps_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.container_apps.name
  resource_group_name = data.azurerm_resource_group.foundry.name
  ttl                 = 60
  records             = [azurerm_container_app_environment.agents.static_ip_address]
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "external_agent" {
  name                = "${local.prefix}-id-ext-agent"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.foundry.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "external_agent_acr_pull" {
  scope                = data.azurerm_container_registry.agents.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.external_agent.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "external_agent_acr_repository_reader" {
  scope                = data.azurerm_container_registry.agents.id
  role_definition_name = "Container Registry Repository Reader"
  principal_id         = azurerm_user_assigned_identity.external_agent.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app" "external_agent" {
  name                         = "${local.prefix}-ca-ext-agent"
  container_app_environment_id = azurerm_container_app_environment.agents.id
  resource_group_name          = data.azurerm_resource_group.foundry.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.external_agent.id]
  }

  registry {
    server   = data.azurerm_container_registry.agents.login_server
    identity = azurerm_user_assigned_identity.external_agent.id
  }

  secret {
    name  = "applicationinsights-connection-string"
    value = data.azurerm_application_insights.foundry.connection_string
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "external-agent"
      image  = var.external_agent_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = var.foundry_project_endpoint
      }

      env {
        name  = "AZURE_AI_MODEL_DEPLOYMENT_NAME"
        value = var.model_deployment_name
      }

      env {
        name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        secret_name = "applicationinsights-connection-string"
      }

      env {
        name  = "OTEL_SERVICE_NAME"
        value = "external-agent"
      }

      liveness_probe {
        transport        = "HTTP"
        port             = 8080
        path             = "/healthz"
        interval_seconds = 30
      }

      readiness_probe {
        transport        = "HTTP"
        port             = 8080
        path             = "/healthz"
        interval_seconds = 10
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [
    azurerm_private_dns_a_record.container_apps_wildcard,
    azurerm_role_assignment.external_agent_acr_pull,
    azurerm_role_assignment.external_agent_acr_repository_reader,
  ]
}

resource "azurerm_role_assignment" "external_agent_model_user" {
  scope                = local.foundry_account_id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.external_agent.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "external_agent_monitoring" {
  scope                = data.azurerm_application_insights.foundry.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.external_agent.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_monitor_diagnostic_setting" "container_app" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_container_app.external_agent.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.central.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_api_management_backend" "external_agent" {
  name                = "external-agent"
  resource_group_name = data.azurerm_resource_group.foundry.name
  api_management_name = data.azurerm_api_management.ai_gateway.name
  protocol            = "http"
  url                 = "https://${azurerm_container_app.external_agent.ingress[0].fqdn}"
}

resource "azurerm_api_management_api" "external_agent" {
  name                  = "external-agent-v1"
  resource_group_name   = data.azurerm_resource_group.foundry.name
  api_management_name   = data.azurerm_api_management.ai_gateway.name
  revision              = "1"
  display_name          = "External Agent API"
  path                  = "agents/external"
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "external_agent_responses" {
  operation_id        = "create-response"
  api_name            = azurerm_api_management_api.external_agent.name
  api_management_name = data.azurerm_api_management.ai_gateway.name
  resource_group_name = data.azurerm_resource_group.foundry.name
  display_name        = "Create response"
  method              = "POST"
  url_template        = "/v1/responses"
}

resource "azurerm_api_management_api_policy" "external_agent" {
  api_name            = azurerm_api_management_api.external_agent.name
  api_management_name = data.azurerm_api_management.ai_gateway.name
  resource_group_name = data.azurerm_resource_group.foundry.name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        <validate-azure-ad-token tenant-id="${var.tenant_id}" header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
          <audiences>
            <audience>${var.api_audience}</audience>
          </audiences>
        </validate-azure-ad-token>
        <set-backend-service backend-id="${azurerm_api_management_backend.external_agent.name}" />
        <set-header name="Authorization" exists-action="delete" />
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
      <on-error><base /></on-error>
    </policies>
  XML
}

resource "azurerm_api_management_api_diagnostic" "external_agent" {
  identifier                = "applicationinsights"
  resource_group_name       = data.azurerm_resource_group.foundry.name
  api_management_name       = data.azurerm_api_management.ai_gateway.name
  api_name                  = azurerm_api_management_api.external_agent.name
  api_management_logger_id  = local.apim_logger_id
  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = false
  verbosity                 = "information"
  http_correlation_protocol = "W3C"
}

resource "azurerm_api_management_backend" "fabric_agent" {
  count = var.fabric_agent_backend_url == "" ? 0 : 1

  name                = "fabric-iq-agent"
  resource_group_name = data.azurerm_resource_group.foundry.name
  api_management_name = data.azurerm_api_management.ai_gateway.name
  protocol            = "http"
  url                 = var.fabric_agent_backend_url
}

resource "azurerm_api_management_api" "fabric_agent" {
  count = var.fabric_agent_backend_url == "" ? 0 : 1

  name                  = "fabric-iq-agent-v1"
  resource_group_name   = data.azurerm_resource_group.foundry.name
  api_management_name   = data.azurerm_api_management.ai_gateway.name
  revision              = "1"
  display_name          = "Fabric IQ Agent API"
  path                  = "agents/fabric-iq"
  protocols             = ["https"]
  subscription_required = false
}

resource "azurerm_api_management_api_operation" "fabric_agent_responses" {
  count = var.fabric_agent_backend_url == "" ? 0 : 1

  operation_id        = "create-response"
  api_name            = azurerm_api_management_api.fabric_agent[0].name
  api_management_name = data.azurerm_api_management.ai_gateway.name
  resource_group_name = data.azurerm_resource_group.foundry.name
  display_name        = "Create response"
  method              = "POST"
  url_template        = "/v1/responses"
}

resource "azurerm_api_management_api_policy" "fabric_agent" {
  count = var.fabric_agent_backend_url == "" ? 0 : 1

  api_name            = azurerm_api_management_api.fabric_agent[0].name
  api_management_name = data.azurerm_api_management.ai_gateway.name
  resource_group_name = data.azurerm_resource_group.foundry.name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        <validate-azure-ad-token tenant-id="${var.tenant_id}" header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized">
          <audiences>
            <audience>${var.api_audience}</audience>
          </audiences>
        </validate-azure-ad-token>
        <set-backend-service backend-id="${azurerm_api_management_backend.fabric_agent[0].name}" />
      </inbound>
      <backend><base /></backend>
      <outbound><base /></outbound>
      <on-error><base /></on-error>
    </policies>
  XML
}

resource "azurerm_api_management_api_diagnostic" "fabric_agent" {
  count = var.fabric_agent_backend_url == "" ? 0 : 1

  identifier                = "applicationinsights"
  resource_group_name       = data.azurerm_resource_group.foundry.name
  api_management_name       = data.azurerm_api_management.ai_gateway.name
  api_name                  = azurerm_api_management_api.fabric_agent[0].name
  api_management_logger_id  = local.apim_logger_id
  sampling_percentage       = 100
  always_log_errors         = true
  log_client_ip             = false
  verbosity                 = "information"
  http_correlation_protocol = "W3C"
}