#!/usr/bin/env bash
# Packages the GUI into a standalone TrayOpsApp.app bundle (no Xcode).
# Builds the release binary, assembles the bundle, writes Info.plist, copies the
# icon and ad-hoc code-signs it. Output: dist/TrayOpsApp.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

VERSION="${TRAYOPS_VERSION:-0.1.0}"
APP="${ROOT}/dist/TrayOpsApp.app"
CONTENTS="${APP}/Contents"

echo "==> swift build -c release"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/TrayOpsApp"
[ -x "${BIN}" ] || { echo "error: ${BIN} not found"; exit 1; }

echo "==> assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
cp "${BIN}" "${CONTENTS}/MacOS/TrayOpsApp"

if [ -f "${ROOT}/Resources/AppIcon.icns" ]; then
    cp "${ROOT}/Resources/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"
else
    echo "note: Resources/AppIcon.icns missing — run scripts/generate-icon.sh first"
fi

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TrayOps</string>
    <key>CFBundleDisplayName</key><string>TrayOps</string>
    <key>CFBundleIdentifier</key><string>com.earthw0rm.trayops</string>
    <key>CFBundleExecutable</key><string>TrayOpsApp</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "==> ad-hoc code signing"
codesign --force --deep --sign - "${APP}" || echo "note: code signing failed (the app still runs locally)"

echo "Built ${APP}"
echo "Install with:  cp -R \"${APP}\" /Applications/  &&  open /Applications/TrayOpsApp.app"
