#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# check-sensitive.sh — block commits that leak customer / partner identity.
#
# How it works:
#   * Reads a DENYLIST of forbidden strings (customer name, partner names,
#     real subscription short-codes, org prefixes, etc.).
#   * The real denylist lives in _private/denylist.txt (git-ignored) so the
#     forbidden strings themselves are never published in this public repo.
#   * A committed baseline (below) catches obvious mistakes even if the
#     private file is missing.
#   * Scans STAGED content only. Fails the commit on any match.
#
# Install as a pre-commit hook (see .pre-commit-config.yaml) or run manually:
#   ./scripts/check-sensitive.sh
# ---------------------------------------------------------------------------
set -euo pipefail

RED=$'\033[0;31m'; YEL=$'\033[0;33m'; GRN=$'\033[0;32m'; NC=$'\033[0m'
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PRIVATE_DENYLIST="${ROOT}/_private/denylist.txt"

# Baseline patterns that are ALWAYS forbidden in committed content.
# (Generic — safe to publish. Add customer-specific terms to the private file.)
BASELINE_PATTERNS=(
  # Real Azure identifiers should never be committed outside *.example files.
  'subscription_id[[:space:]]*=[[:space:]]*"[0-9a-f]{8}-'
  'tenant_id[[:space:]]*=[[:space:]]*"[0-9a-f]{8}-'
)

# Load private, customer-specific patterns if available.
EXTRA_PATTERNS=()
if [[ -f "${PRIVATE_DENYLIST}" ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    EXTRA_PATTERNS+=("${line}")
  done < "${PRIVATE_DENYLIST}"
else
  echo "${YEL}⚠  _private/denylist.txt not found — running with baseline patterns only.${NC}"
  echo "${YEL}   Create it from _private/denylist.txt.example to catch customer-specific terms.${NC}"
fi

ALL_PATTERNS=()
[[ ${#BASELINE_PATTERNS[@]} -gt 0 ]] && ALL_PATTERNS+=("${BASELINE_PATTERNS[@]}")
[[ ${#EXTRA_PATTERNS[@]} -gt 0 ]] && ALL_PATTERNS+=("${EXTRA_PATTERNS[@]}")

# Collect staged files (added/copied/modified), skip deletions and binaries.
# Portable (no mapfile — macOS ships bash 3.2).
STAGED=()
while IFS= read -r line; do
  [[ -n "${line}" ]] && STAGED+=("${line}")
done < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
if [[ ${#STAGED[@]} -eq 0 ]]; then
  exit 0
fi

FAIL=0
for f in "${STAGED[@]}"; do
  # Never scan the private overlay or example files.
  [[ "${f}" == _private/* ]] && continue
  [[ "${f}" == *.example || "${f}" == *.example.* ]] && continue
  # Only scan text files.
  if ! git show ":${f}" 2>/dev/null | grep -Iq . ; then
    continue
  fi
  content="$(git show ":${f}" 2>/dev/null || true)"
  for pat in "${ALL_PATTERNS[@]}"; do
    if grep -nEi -- "${pat}" <<<"${content}" >/dev/null 2>&1; then
      echo "${RED}✖ Forbidden pattern in ${f}${NC}  (pattern: ${pat})"
      FAIL=1
    fi
  done
done

if [[ ${FAIL} -ne 0 ]]; then
  echo ""
  echo "${RED}Commit blocked: content matches the sensitive-terms denylist.${NC}"
  echo "Move real values into _private/ (git-ignored) and use <TOKEN> placeholders in public files."
  exit 1
fi

echo "${GRN}✓ No sensitive terms detected in staged changes.${NC}"
exit 0
