# `_private/` — the private overlay (git-ignored)

This folder holds the **real** values that must never be published:

- `denylist.txt` — customer/partner terms the commit guard blocks
- `*.private.tfvars` — real subscription IDs, tenant IDs, org prefix, CIDRs
- the original design document(s) (`.docx`) if you keep them here

Everything in this folder is git-ignored **except** files ending in `.example`
and this `README.md`. That lets the repo ship templates without ever exposing
real data.

## Setup

```bash
cp _private/denylist.txt.example       _private/denylist.txt
cp _private/enterprise.tfvars.example  _private/enterprise.private.tfvars
# then edit the copies with the real values
```

## Rule of thumb

If a value would tell a reader **who the customer is**, **who the partner is**,
or **which real Azure tenant/subscription this is** — it belongs here, not in
the public tree. Public files use `<TOKEN>` placeholders instead.
