#!/usr/bin/env bash
# Removes a permanent install: the TrayOpsApp.app bundle, the `trayops` CLI and
# the login item. Pass --purge to also delete the local account data.
#
# Note: this does NOT revert your git identity or ~/.ssh/config — those are your
# real configuration, not owned by TrayOps.
set -euo pipefail

BIN_DIR="${TRAYOPS_BIN_DIR:-/usr/local/bin}"
APP="/Applications/TrayOpsApp.app"

echo "==> stopping TrayOps if running"
killall TrayOpsApp 2>/dev/null || true

echo "==> removing login item (if present)"
osascript -e 'tell application "System Events" to delete login item "TrayOpsApp"' 2>/dev/null || true

echo "==> removing ${APP}"
rm -rf "${APP}"

if [ -e "${BIN_DIR}/trayops" ]; then
    echo "==> removing ${BIN_DIR}/trayops"
    if [ -w "${BIN_DIR}" ]; then
        rm -f "${BIN_DIR}/trayops"
    else
        sudo rm -f "${BIN_DIR}/trayops"
    fi
fi

if [ "${1:-}" = "--purge" ]; then
    echo "==> removing local account data and logs"
    rm -rf "${HOME}/Library/Application Support/TrayOps"
    rm -rf "${HOME}/Library/Logs/TrayOps"
fi

echo "TrayOps uninstalled."
