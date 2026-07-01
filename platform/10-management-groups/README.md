# Stage 10 — Management Groups

Creates the `mgmt` / `workloads` / `monitor` / `sandbox` management group
hierarchy. Extend with subscription placement and Azure Policy assignments.

```bash
cd platform/10-management-groups
terraform init -backend-config=../../_private/backend.hcl
terraform apply -var-file=../../_private/enterprise.private.tfvars
```
