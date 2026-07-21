# Stage 40 — Monitoring

Private central observability for the landing zone. This stage creates:

- A central Log Analytics workspace with public ingestion, public query, and
	local authentication disabled.
- One Azure Monitor Private Link Scope (AMPLS) with ingestion and query access
	modes set to `PrivateOnly`.
- One AMPLS private endpoint in the dedicated hub
	`AzureMonitorPrivateEndpointSubnet` (`/27` minimum).
- The five Azure Monitor private DNS zones, centrally linked to the hub VNet.
- An AMPLS scoped-service association for the central workspace.

Set `azure_monitor_blob_private_dns_zone_resource_group_name` when the hub is
already linked to a `privatelink.blob.core.windows.net` zone, such as the zone
used by a private Terraform-state endpoint. Stage 40 reuses that zone and
preserves its records; when the variable is null, Stage 40 creates the zone in
the connectivity resource group.

Apply `platform/20-connectivity-hub` first so the dedicated private-endpoint
subnet exists. The Stage 40 identity needs permissions in both the monitoring
subscription and the connectivity subscription.

Workload Application Insights components and data collection endpoints must be
added to `azure_monitor_private_link_scope_id`. For workspace-based Application
Insights, associate both the Application Insights component and its underlying
Log Analytics workspace when they aren't already using this central workspace.
Workload stages must reuse `azure_monitor_private_dns_zone_ids` and either link
those zones to their spoke VNet or configure the spoke to resolve through the
hub DNS path. Do not create another AMPLS or duplicate Azure Monitor zones in a
network that shares this DNS namespace.

Diagnostic settings deliver platform logs over a Microsoft-managed channel and
continue to work when public workspace ingestion is disabled. Interactive Log
Analytics and Application Insights queries must originate from a client that can
resolve and reach the AMPLS private endpoint.

The current Microsoft Foundry network-isolation documentation does not support
the native Foundry **Traces** experience with private Application Insights.
Private OpenTelemetry ingestion from network-injected application compute is a
separate supported path; treat native traces and trace-based evaluations as a
deployment stop gate until Microsoft removes that limitation.
