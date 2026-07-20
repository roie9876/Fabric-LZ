#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# render-fabric-svg.sh — build the marketing-style Fabric workspace Private Link
# diagram and rasterize it to a PNG for the README.
#
#   Source  : scripts/gen-fabric-svg.py  ->  docs/diagrams/05-fabric-private-link.svg
#   Output  : docs/images/05-fabric-private-link.png  (3200x1800, 16:9)
#
# macOS only: uses the built-in `qlmanage` (Quick Look, WebKit) to rasterize the
# SVG, then `sips` to center-crop the square export back to 16:9. No extra deps.
# The SVG is fully self-contained (official Fabric icons embedded as data URIs).
# ---------------------------------------------------------------------------
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="${ROOT}/docs/diagrams/05-fabric-private-link.svg"
PNG="${ROOT}/docs/images/05-fabric-private-link.png"

python3 "${ROOT}/scripts/gen-fabric-svg.py"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
qlmanage -t -s 3200 -o "${TMP}" "${SVG}" >/dev/null 2>&1
sips -c 1664 3200 "${TMP}/05-fabric-private-link.svg.png" --out "${PNG}" >/dev/null 2>&1
echo "-> ${PNG}"
