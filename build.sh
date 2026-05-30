#!/usr/bin/env bash
# Build UsageDash.app — a menu bar agent (no dock icon).
# Usage:  ./build.sh [version]
#   version: optional, defaults to 0.1.0 (or $VERSION env). Goes into Info.plist
#            and the .zip filename in dist/.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="UsageDash"
BUNDLE_ID="io.github.doniyorniazov.UsageDash"
APP_DIR="${APP_NAME}.app"
VERSION="${1:-${VERSION:-0.1.0}}"

echo "==> swift build -c release  (version ${VERSION})"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
if [[ ! -x "${BIN_PATH}" ]]; then
  echo "Binary not found at ${BIN_PATH}" >&2
  exit 1
fi

echo "==> Assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
# Copy loose assets so Bundle.main can find them. Anything besides README.md.
find Sources/UsageDash/Resources -type f ! -name "README.md" -exec cp {} "${APP_DIR}/Contents/Resources/" \;

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Claude Usage</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code sign"
codesign --force --sign - "${APP_DIR}" >/dev/null

echo "==> Packaging dist/${APP_NAME}-v${VERSION}.zip"
mkdir -p dist
ZIP_PATH="dist/${APP_NAME}-v${VERSION}.zip"
rm -f "${ZIP_PATH}"
# `ditto` is the right tool on macOS — preserves resource forks, extended
# attributes, and the code signature, which a plain `zip` strips.
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo
echo "Built ${APP_DIR}"
echo "Zipped ${ZIP_PATH}  ($(du -h "${ZIP_PATH}" | cut -f1))"
echo
echo "Run locally:   open ${APP_DIR}"
echo "Install:       mv ${APP_DIR} /Applications/"
