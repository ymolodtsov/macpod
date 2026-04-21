#!/usr/bin/env bash
# Build MacPod.app — a proper macOS .app bundle containing the executable
# plus the MediaRemoteAdapter framework and the perl shim.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP_NAME="MacPod"
APP_DIR="build/${APP_NAME}.app"

echo "==> Building Swift executable (${CONFIG})"
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)/${APP_NAME}"
if [ ! -x "${BIN_PATH}" ]; then
    echo "binary not found at ${BIN_PATH}" >&2
    exit 1
fi

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>MacPod</string>
    <key>CFBundleDisplayName</key><string>MacPod</string>
    <key>CFBundleExecutable</key><string>MacPod</string>
    <key>CFBundleIdentifier</key><string>dev.yury.macpod</string>
    <key>CFBundleVersion</key><string>5</string>
    <key>CFBundleShortVersionString</key><string>0.5</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>MacPod</string>
</dict>
</plist>
PLIST

cp -R Resources/MediaRemoteAdapter.framework "${APP_DIR}/Contents/Resources/"
cp Resources/mediaremote-adapter.pl "${APP_DIR}/Contents/Resources/"
cp Resources/MacPod.icns "${APP_DIR}/Contents/Resources/"

echo "==> Ad-hoc codesigning"
codesign --force --deep --sign - "${APP_DIR}/Contents/Resources/MediaRemoteAdapter.framework"
codesign --force --sign - "${APP_DIR}"

echo "==> Done: ${APP_DIR}"
