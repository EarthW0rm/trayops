#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from scripts/generate-icon.swift using the
# system `iconutil` (no Xcode required). Also keeps a 1024px PNG preview.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT_DIR="${ROOT}/Resources"

mkdir -p "${OUT_DIR}"
swift "${ROOT}/scripts/generate-icon.swift" "${ICONSET}"
iconutil -c icns "${ICONSET}" -o "${OUT_DIR}/AppIcon.icns"
cp "${ICONSET}/icon_512x512@2x.png" "${OUT_DIR}/AppIcon-preview.png"

echo "Wrote ${OUT_DIR}/AppIcon.icns and AppIcon-preview.png"
