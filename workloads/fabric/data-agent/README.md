# Fabric IQ Data Agent applied configuration

This folder records the non-secret applied configuration for the published Fabric Data Agent and its Foundry prompt agent.

## Applied resources

- Fabric workspace: `azr-sbx-lab-0001-fabws-public`
- Fabric Data Agent: `da_sales_intelligence`
- Semantic model: `sm_salesorders_public`
- Native Foundry connection: `fabric-sales-native`
- Foundry prompt agent: `fabric-iq-prompt-agent`, version 6
- Orchestration model: `gpt-4.1-mini` (`GlobalStandard`, capacity 10)

The native Microsoft Fabric connection uses Custom Keys named exactly `workspace-id` and `artifact-id`. Underscore names are not recognized by the Fabric tool runtime.

## Root-cause fixes

1. `gpt-5-mini` was rejected by the portal as unsupported for Fabric Data Agent. The prompt agent now uses `gpt-4.1-mini`.
2. The first connection used `workspace_id` and `artifact_id`. The native wizard requires `workspace-id` and `artifact-id`.
3. The published semantic source had `elements: []`. The Data Agent could invoke but could not construct a semantic-model query. The applied definition selects `SalesOrders` and its four columns.
4. Source instructions now define total sales as `SUM(SalesOrders[Amount])`, require DAX, and prohibit the nonexistent `TotalAmount` column and SQL.

## Verification

Direct DAX, run as the same signed-in user:

```dax
EVALUATE
ROW(
    "TotalSales", SUM(SalesOrders[Amount]),
    "OrderCount", COUNTROWS(SalesOrders)
)
```

Applied result on 2026-07-22:

- `TotalSales`: `14,476.47`
- `OrderCount`: `10`

Foundry version 6 asked `What is the total sales amount across all orders?` and returned `14,476.47` with a Fabric run citation. The matching values are the acceptance gate.

## Updating Fabric

Export the Data Agent with `POST /v1/workspaces/{workspaceId}/items/{itemId}/getDefinition`, update both draft and published copies of `stage_config.json` and the semantic-model `datasource.json`, then submit the complete parts array to `POST /v1/workspaces/{workspaceId}/items/{itemId}/updateDefinition`. Poll the operation URL until `Succeeded`, export again, and compare the published files with this folder.

Do not accept a generic answer or a tool-call marker as proof of data access. Establish a direct DAX baseline and require the cited Fabric answer to match it.
