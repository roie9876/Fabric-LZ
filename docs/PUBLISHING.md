# Publishing safely — keeping the repo customer-neutral

This repo is designed to be **public**. It documents a landing-zone *pattern*,
not a specific customer deployment. Follow these rules so no customer or partner
identity is ever exposed.

## What must never be committed

| Category | Examples | Where it goes instead |
|---|---|---|
| Customer name | company name (any language/script) | `_private/` only |
| Partner / author names | people, consulting firm | `_private/` only |
| Real Azure identity | subscription IDs, tenant IDs | `_private/*.private.tfvars` |
| Real naming values | org prefix, subscription short-codes | `_private/` (tokens in public) |
| Real address plan | actual CIDRs, IP addresses | `_private/` (`x.x.x.x` in public) |
| Vendor lock-in signal | specific SWG/CNAPP brand tied to customer | generic module + private config |
| Source documents | the original `.docx` LLD | `_private/` (git-ignored `*.docx`) |

## How it's enforced (defense in depth)

1. **`.gitignore`** — ignores `_private/`, all `*.tfvars` (except `*.example`),
   `*.env`, `*.docx`, keys, and state.
2. **`scripts/check-sensitive.sh`** — a pre-commit hook that scans *staged*
   content against a denylist. The real denylist lives in the git-ignored
   `_private/denylist.txt`, so the forbidden words themselves are never
   published.
3. **gitleaks** — pre-commit hook **and** GitHub Action (`.github/workflows/secret-scan.yml`)
   catch secrets and hard-coded GUIDs.
4. **`pre-commit`** — `terraform_fmt`, `terraform_validate`, private-key
   detection, merge-conflict checks.

## First-commit discipline

Because the source `.docx` and possibly real values may already exist in the
working folder, the goal is to **keep them out of the very first commit** rather
than scrub history later. Before `git init` / first push:

```bash
# verify nothing sensitive is staged
git add -A
pre-commit run --all-files          # or: ./scripts/check-sensitive.sh
git status                          # confirm _private/ and *.docx are NOT listed
```

If anything sensitive ever does land in history, treat the tokens as
compromised (rotate them) and rewrite history with `git filter-repo` before the
repo is made public.

## Token conventions used in public files

| Token | Meaning |
|---|---|
| `<ORG>` / `org` | organization naming prefix |
| `<SUBCODE>` / `0000` | subscription short-code used in resource names |
| `x.x.x.x` / `x.x.x.x/xx` | placeholder IP / CIDR |
| `00000000-0000-0000-0000-000000000000` | placeholder GUID |
