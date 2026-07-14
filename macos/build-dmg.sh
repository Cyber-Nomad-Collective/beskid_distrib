#!/usr/bin/env bash
# Create a portable Beskid.app DMG from the immutable CLI and LSP assets.
# Usage: build-dmg.sh <version> <build-dir> <assets-dir>
set -euo pipefail

VERSION="${1:?version (SemVer)}"
BUILD_DIR="${2:?directory containing beskid and beskid_lsp}"
ASSETS_DIR="${3:?assets directory}"

[[ -x "${BUILD_DIR}/beskid" ]] || { echo "Missing executable ${BUILD_DIR}/beskid" >&2; exit 1; }
[[ -x "${BUILD_DIR}/beskid_lsp" ]] || { echo "Missing executable ${BUILD_DIR}/beskid_lsp" >&2; exit 1; }
[[ -f "${ASSETS_DIR}/icons/beskid-512.png" ]] || { echo "Missing app icon source" >&2; exit 1; }

stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT
app="${stage}/Beskid.app"
contents="${app}/Contents"
macos="${contents}/MacOS"
resources="${contents}/Resources"
mkdir -p "${macos}" "${resources}"

cp "${BUILD_DIR}/beskid" "${macos}/beskid"
cp "${BUILD_DIR}/beskid_lsp" "${macos}/beskid_lsp"
cp "${ASSETS_DIR}/icons/beskid-512.png" "${resources}/beskid-512.png"
chmod 0755 "${macos}/beskid" "${macos}/beskid_lsp"

cat >"${contents}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>beskid</string>
  <key>CFBundleIdentifier</key><string>org.beskid-lang.beskid</string>
  <key>CFBundleName</key><string>Beskid</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
</dict></plist>
EOF

out="beskid-${VERSION}-macos-arm64.dmg"
hdiutil create -volname Beskid -srcfolder "${app}" -ov -format UDZO "${out}"
echo "built ${out}"
