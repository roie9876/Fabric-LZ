# Stage 00 — Bootstrap

Creates the Terraform **remote-state** storage (resource group + GRS storage
account with versioning + private container). Run this first.

## Deploy

```bash
cd platform/00-bootstrap

# First run uses a local backend (state storage doesn't exist yet).
terraform init
terraform apply -var-file=../../_private/enterprise.private.tfvars

# Then create _private/backend.hcl from the outputs and migrate:
#   resource_group_name  = "<state_resource_group>"
#   storage_account_name = "<state_storage_account>"
#   container_name       = "tfstate"
#   key                  = "platform-00-bootstrap.tfstate"
terraform init -migrate-state -backend-config=../../_private/backend.hcl
```

## Notes

- `shared_access_key_enabled = false` → state access is via Entra RBAC only.
- Extend this stage with GitHub Actions OIDC federated identity credentials so
  CI can authenticate without secrets.
