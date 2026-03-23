#!/usr/bin/env bash
# Build docs/reports/poc-architecture.pdf from architecture.md + standards.md.
# Requires: pandoc, a PDF engine (e.g. pdflatex from MacTeX / TeX Live),
# Node (per .nvmrc), mermaid-filter (npm install -g mermaid-filter), Chromium/Puppeteer.
# For SVG diagrams (format=svg in fences): librsvg (brew install librsvg) for rsvg-convert.
# On Windows, use mermaid-filter.cmd as the filter instead of mermaid-filter.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Use system Chrome if Chromium isn't available (e.g. sandbox or first run)
if [[ -z "${PUPPETEER_EXECUTABLE_PATH:-}" ]] && [[ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
fi

mkdir -p docs/reports

exec pandoc -s --toc \
  -F mermaid-filter \
  --lua-filter="$ROOT/scripts/pandoc/rewrite-crossdoc-links.lua" \
  docs/architecture.md docs/standards.md \
  -o docs/reports/poc-architecture.pdf
