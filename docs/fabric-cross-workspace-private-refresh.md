# Cross-workspace semantic-model refresh into a private Workspace A

> **This procedure now lives in the deployment guide.**
> The full, maintained content — the problem, root cause with Microsoft
> citations, the `z{xy}` connection-string recipe, DNS chain, gateway binding,
> end-to-end proof, automation, and operational gotchas — is
> **[Appendix A of the deployment guide](../DEPLOYMENT-GUIDE.md#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a)**.
>
> This page is kept only as a stable link target so existing references keep
> working. It intentionally does not duplicate the appendix, to avoid two
> diverging copies.

## Quick summary

After Workspace A is locked to private-only, a public Workspace B semantic model
that reads Workspace A over an ordinary cloud connection fails to refresh with
`CrossWorkspaceRequestNotAllowed`. The supported fix is to bind the model to a
data gateway (the OPDG or a VNet gateway) using the workspace-private
`z{xy}` datawarehouse connection string. See
[Appendix A](../DEPLOYMENT-GUIDE.md#appendix-a-cross-workspace-semantic-model-refresh-into-a-private-workspace-a)
for the step-by-step procedure.

## References

- Cross-workspace communication — https://learn.microsoft.com/en-us/fabric/security/security-cross-workspace-communication
- Workspace-level private links overview — https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-overview
- Supported scenarios and limitations — https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-support
- VNet gateway walkthrough — https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-power-bi-virtual-network
- OPDG walkthrough — https://learn.microsoft.com/en-us/fabric/security/security-workspace-private-links-example-on-premises-data-gateway
