# Examples

Two starting points. Copy the `.example` file, drop the `.example` suffix (which
makes it git-ignored), and fill in real values — or point Terraform at your
`_private/*.private.tfvars`.

| Example | Purpose |
|---|---|
| `lab/lab.tfvars.example` | Small sandbox with safe placeholder values — mirror the enterprise shape cheaply |
| `enterprise/enterprise.tfvars.example` | The full enterprise-shaped topology, fully tokenized |

```bash
# Lab
cp examples/lab/lab.tfvars.example examples/lab/lab.tfvars   # now git-ignored
terraform apply -var-file=../../examples/lab/lab.tfvars

# Enterprise (real values live in _private/)
terraform apply -var-file=../../_private/enterprise.private.tfvars
```

Never put real subscription IDs, tenant IDs, org prefixes, or CIDRs in these
public example files — those belong in `_private/`.
