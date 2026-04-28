#!/bin/bash

set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
error()   { echo "[ERROR] $*" >&2; exit 1; }

# ── Build ─────────────────────────────────────────────────────────────────────
cd "$(dirname "$0")/.." || error "Failed to change directory."

info "Cleaning dist/..."
rm -rf ./dist && mkdir ./dist

info "Locking and exporting dependencies..."
uv sync && uv lock
uv export --frozen --no-dev --no-editable -o ./dist/requirements.txt

info "Installing dependencies into dist/package/..."
uv run --with pip pip install -r ./dist/requirements.txt --target ./dist/package

info "Copying source code..."
cp -r ./src/ ./dist/package

info "Zipping package..."
cd dist/package && zip -r ../lambda.zip . && cd ../..

success "Build complete: dist/lambda.zip"