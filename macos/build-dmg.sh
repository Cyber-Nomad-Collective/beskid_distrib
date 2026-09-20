#!/usr/bin/env bash
# Create a portable Beskid.app DMG from the verified full target bundle.
# Usage: build-dmg.sh <version> <build-dir> <assets-dir>
set -euo pipefail

VERSION="${1:?version (SemVer)}"
BUILD_DIR="${2:?verified target bundle root}"
ASSETS_DIR="${3:?assets directory}"
DISTRIB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ -x "${BUILD_DIR}/bin/beskid" ]] || { echo "Missing executable ${BUILD_DIR}/bin/beskid" >&2; exit 1; }
[[ -x "${BUILD_DIR}/bin/beskid_lsp" ]] || { echo "Missing executable ${BUILD_DIR}/bin/beskid_lsp" >&2; exit 1; }
[[ -x "${BUILD_DIR}/bin/beskid-up" ]] || { echo "Missing executable ${BUILD_DIR}/bin/beskid-up" >&2; exit 1; }
[[ -d "${BUILD_DIR}/lib/beskid-runtime/abi-5" ]] || { echo "Missing ABI-v5 runtime kit" >&2; exit 1; }
[[ -f "${BUILD_DIR}/beskid_corelib/corelib.bproj" ]] || { echo "Missing bundled corelib" >&2; exit 1; }
[[ -f "${ASSETS_DIR}/icons/beskid-512.png" ]] || { echo "Missing app icon source" >&2; exit 1; }
[[ -f "${ASSETS_DIR}/dmg-background.png" ]] || { echo "Missing DMG background image" >&2; exit 1; }

stage="$(mktemp -d)"
mount=""
device=""
attached=0
cleanup() {
  if [[ "${attached}" == 1 ]]; then
    hdiutil detach "${mount}" -quiet || true
  fi
  rm -rf "${stage}"
}
trap cleanup EXIT
app="${stage}/Beskid.app"
contents="${app}/Contents"
macos="${contents}/MacOS"
resources="${contents}/Resources"
toolchain="${resources}/toolchain"
mkdir -p "${macos}" "${resources}" "${toolchain}"

cp -a "${BUILD_DIR}/." "${toolchain}/"
cat >"${macos}/beskid" <<'EOF'
#!/bin/sh
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "${here}/../Resources/toolchain/bin/beskid" "$@"
EOF
cat >"${macos}/beskid_lsp" <<'EOF'
#!/bin/sh
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "${here}/../Resources/toolchain/bin/beskid_lsp" "$@"
EOF
cp "${ASSETS_DIR}/icons/beskid-512.png" "${resources}/beskid-512.png"
cp "${DISTRIB_ROOT}/LICENSE" "${resources}/LICENSE.txt"
cp "${DISTRIB_ROOT}/NOTICE" "${resources}/NOTICE.txt"
chmod 0755 "${macos}/beskid" "${macos}/beskid_lsp" \
  "${toolchain}/bin/beskid" "${toolchain}/bin/beskid_lsp" "${toolchain}/bin/beskid-up"

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

volume="${stage}/Beskid"
volume_label="Beskid ${VERSION}"
mkdir -p "${volume}/.background"
cp -a "${app}" "${volume}/Beskid.app"
cp "${ASSETS_DIR}/dmg-background.png" "${volume}/.background/background.png"
ln -s /Applications "${volume}/Applications"

rw_image="${stage}/Beskid-rw.dmg"
hdiutil create -volname "${volume_label}" -srcfolder "${volume}" -ov -format UDRW "${rw_image}" >/dev/null
attach_output="$(hdiutil attach "${rw_image}" -readwrite -noverify -noautoopen)"
device="$(awk '$1 ~ /^\/dev\// { print $1; exit }' <<<"${attach_output}")"
mount="$(awk '$1 ~ /^\/dev\// {
  path=$0
  sub(/^.*\t/, "", path)
  if (path ~ /^\//) {
    print path
    exit
  }
}' <<<"${attach_output}")"
[[ -n "${device}" && -d "${mount}" ]] || { echo "Unable to mount writable DMG" >&2; exit 1; }
attached=1

# Finder persists this layout in .DS_Store, so every mounted copy presents a
# clear drag-to-install flow instead of a plain archive window.
configure_finder_layout() {
osascript <<EOF
with timeout of 30 seconds
tell application "Finder"
  tell disk "${volume_label}"
    -- Finder creates the root window asynchronously after hdiutil attaches.
    -- Give it one open/close cycle before writing the persistent DS_Store.
    open
    delay 5
    close
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {300, 150, 1200, 690}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 112
    set text size of theViewOptions to 14
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "Beskid.app" of container window to {225, 330}
    set position of item "Applications" of container window to {675, 330}
    close
    open
    update without registering applications
  end tell
end tell
end timeout
EOF
}

# Finder may still be opening the mounted disk when the first AppleEvent is
# delivered. Retry a bounded number of times, but fail the package rather than
# shipping a DMG that lacks the guided install layout.
for attempt in 1 2 3; do
  if configure_finder_layout; then
    break
  fi

  if [[ "${attempt}" == 3 ]]; then
    echo "Finder did not persist the DMG layout after ${attempt} attempts" >&2
    exit 1
  fi

  echo "Finder layout attempt ${attempt} failed; retrying" >&2
  sleep 5
done
sync
hdiutil detach "${mount}" -quiet
attached=0

out="beskid-${VERSION}-macos-arm64.dmg"
hdiutil convert "${rw_image}" -ov -format UDZO -o "${out}" >/dev/null
echo "built ${out}"
