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
cleanup() {
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

volume_label="Beskid ${VERSION}"
out="beskid-${VERSION}-macos-arm64.dmg"
# dmgbuild writes Finder's .DS_Store directly. The background and Applications
# shortcut therefore survive a non-interactive CI session where AppleEvents to
# the desktop Finder consistently time out.
dmgbuild_cache="${HOME}/Library/Application Support/Woodpecker/python/dmgbuild-1.6.5"
if ! PYTHONPATH="${dmgbuild_cache}" python3 -c 'import dmgbuild' >/dev/null 2>&1; then
  mkdir -p "${dmgbuild_cache}"
  python3 -m pip install --disable-pip-version-check --target "${dmgbuild_cache}" 'dmgbuild==1.6.5'
fi

settings="${stage}/dmg-settings.py"
cat >"${settings}" <<'EOF'
import os

files = [os.environ["BESKID_DMG_APP"]]
symlinks = {"Applications": "/Applications"}
background = os.environ["BESKID_DMG_BACKGROUND"]
window_rect = ((300, 150), (1200, 690))
icon_size = 112
text_size = 14
icon_locations = {
    "Beskid.app": (225, 330),
    "Applications": (675, 330),
}
format = "UDZO"
EOF

export BESKID_DMG_APP="${app}"
export BESKID_DMG_BACKGROUND="${ASSETS_DIR}/dmg-background.png"
PYTHONPATH="${dmgbuild_cache}" python3 - "${out}" "${volume_label}" "${settings}" <<'PY'
import sys
import dmgbuild

dmgbuild.build_dmg(sys.argv[1], sys.argv[2], settings_file=sys.argv[3])
PY
echo "built ${out}"
