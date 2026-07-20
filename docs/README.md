# Documentation index

The repository documentation is organized by audience. Deployment procedures
live in one runbook; component READMEs describe implementation boundaries; this
directory contains architecture, policy, and troubleshooting references.

## Deployment

- [Customer Deployment Guide](../DEPLOYMENT-GUIDE.md) - authoritative
  end-to-end operator sequence, validation gates, evidence criteria, rollback,
  and troubleshooting matrix.

## Architecture

- [Solution overview](00-overview.md)
- [Landing zone architecture](01-landing-zone.md)
- [Fabric workload architecture](02-fabric-workload.md)
- [Foundry workload architecture](03-foundry-workload.md)
- [Architecture diagrams](diagrams/)
- [Rendered architecture images](images/)

## Component documentation

- [Platform implementation](../platform/README.md)
- [Fabric workload implementation](../workloads/fabric/README.md)
- [Foundry workload implementation](../workloads/foundry/README.md)
- [Simulated on-premises lab](../workloads/onprem-lab/README.md)

## Operations and troubleshooting

- [Fabric cross-workspace refresh after private-workspace lockdown](fabric-cross-workspace-private-refresh.md)
- [OPDG and Fabric firewall rules](fabric-opdg-firewall-rules.md)
- [Naming convention](naming-convention.md)

## Reference-lab evidence

- [Platform Layer 1 as-built deployment](../platform/DEPLOYMENT.md)
- [Fabric reference-lab deployment record](../workloads/fabric/REFERENCE-LAB.md)
- [Fabric screenshots](../workloads/fabric/images/)
- [Fabric API evidence](../workloads/fabric/evidence/)

## Contribution safety

- [Publishing safely](PUBLISHING.md)
- [Private overlay](../_private/README.md)

When content overlaps, update the authoritative document above and link to it
from supporting files instead of copying the procedure.
