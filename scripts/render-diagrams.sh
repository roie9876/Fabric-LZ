#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# render-diagrams.sh — export every .drawio source to a PNG for the README.
#
# Sources: docs/diagrams/*.drawio   ->   Output: docs/images/*.png
#
# Requires draw.io desktop (https://github.com/jgraph/drawio-desktop/releases).
# On macOS the CLI binary lives inside the app bundle.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/docs/diagrams"
OUT="${ROOT}/docs/images"
mkdir -p "${OUT}"

# Locate the draw.io CLI.
DRAWIO="${DRAWIO_BIN:-}"
if [[ -z "${DRAWIO}" ]]; then
  if command -v drawio >/dev/null 2>&1; then
    DRAWIO="$(command -v drawio)"
  elif [[ -x "/Applications/draw.io.app/Contents/MacOS/draw.io" ]]; then
    DRAWIO="/Applications/draw.io.app/Contents/MacOS/draw.io"
  else
    echo "draw.io CLI not found. Install draw.io desktop or set DRAWIO_BIN." >&2
    exit 1
  fi
fi

shopt -s nullglob
for f in "${SRC}"/*.drawio; do
  base="$(basename "${f}" .drawio)"
  echo "rendering ${base}.png"
  "${DRAWIO}" -x -f png --scale 2 -o "${OUT}/${base}.png" --no-sandbox "${f}" >/dev/null 2>&1
done
echo "Done -> ${OUT}"
