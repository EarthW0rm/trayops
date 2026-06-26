#!/usr/bin/env bash
# Permanent local install: builds and installs the TrayOpsApp.app bundle into
# /Applications and the `trayops` CLI into a directory on your PATH.
#
# Override the CLI location with TRAYOPS_BIN_DIR (default: /usr/local/bin).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${TRAYOPS_BIN_DIR:-/usr/local/bin}"
APPS_DIR="/Applications"

# 1. Build the release binaries and package the app bundle.
"${ROOT}/scripts/build-app.sh"

# 2. Install the GUI app bundle.
echo "==> installing TrayOpsApp.app to ${APPS_DIR}"
rm -rf "${APPS_DIR}/TrayOpsApp.app"
cp -R "${ROOT}/dist/TrayOpsApp.app" "${APPS_DIR}/"

# 3. Install the CLI onto the PATH (sudo only if the target needs it).
CLI="$(swift build -c release --show-bin-path)/trayops"
[ -x "${CLI}" ] || { echo "error: ${CLI} not found"; exit 1; }
echo "==> installing trayops CLI to ${BIN_DIR}"
if [ -d "${BIN_DIR}" ] && [ -w "${BIN_DIR}" ]; then
    cp "${CLI}" "${BIN_DIR}/trayops"
else
    echo "    ${BIN_DIR} requires elevated permissions"
    sudo mkdir -p "${BIN_DIR}"
    sudo cp "${CLI}" "${BIN_DIR}/trayops"
fi

echo
echo "Installed:"
echo "  GUI: ${APPS_DIR}/TrayOpsApp.app   (open it, or add to Login Items — see INSTALL.md)"
echo "  CLI: ${BIN_DIR}/trayops"
case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *) echo "  note: ${BIN_DIR} is not on your PATH — add it to your shell profile." ;;
esac
