#!/usr/bin/env bash
# Build docs/reports/poc-architecture.pdf from architecture.md + standards.md.
# Requires: pandoc, and a PDF engine (e.g. pdflatex from MacTeX / TeX Live).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p docs/reports

exec pandoc -s --toc \
  --lua-filter="$ROOT/scripts/pandoc/rewrite-crossdoc-links.lua" \
  docs/architecture.md docs/standards.md \
  -o docs/reports/poc-architecture.pdf
