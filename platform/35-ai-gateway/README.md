# Stage 35 — Private AI Gateway

Deploys Azure API Management Standard v2 in Sweden Central as the private AI
Gateway for Foundry models, Hosted Agents, and tools. The gateway uses an inbound
Private Endpoint and outbound VNet integration through the Foundry spoke.

Apply this root after `workloads/foundry` creates the Foundry VNet, private
endpoint subnet, Application Insights, and central DNS links. Model and Hosted
Agent APIs/policies are configured after the first agent version is deployed.

Application Insights logging uses the APIM system-assigned managed identity and
connection string, with `Monitoring Metrics Publisher` on the private component.
Instrumentation-key-only authentication is not used.

Azure requires public network access during initial APIM service activation.
Bootstrap once with `-var=apim_public_network_access_enabled=true` so Terraform
can create the service and its private endpoint. Immediately run the normal plan
without that override to set public network access to `false`. A deployment is
not complete until the steady-state plan returns no changes.

Standard v2 currently drops `apiVersionConstraint.minApiVersion` from service
updates and reads, so this root intentionally omits AzureRM `min_api_version` to
avoid perpetual drift. Private management access is enforced with
`public_network_access_enabled = false` after bootstrap.