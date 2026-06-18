#!/usr/bin/env bash
# Build the Beskid Windows MSI with WiX v4.
#
# Installs WiX v4 as a dotnet global tool (idempotent), then runs
# `wix build` against beskid.wxs with the version + build/assets dirs passed
# as WiX variables.
#
# Usage: build-msi.sh <version> <build-dir> <assets-dir>
#   version    resolved semver (e.g. 0.4.0)
#   build-dir  directory containing beskid.exe + beskid_lsp.exe (the fetched
#              rolling release assets, renamed)
#   assets-dir beskid_distrib/assets (for beskid.ico)
#
# Output: beskid-<version>-windows-amd64.msi in the caller's CWD.
set -euo pipefail

VERSION="${1:?version (semver)}"
BUILD_DIR="${2:?build-dir (contains beskid.exe + beskid_lsp.exe)}"
ASSETS_DIR="${3:?assets-dir (beskid_distrib/assets)}"

DISTRIB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# WiX v4 dotnet tool. Add to PATH for this shell.
dotnet tool install --global wix >/dev/null 2>&1 || true
export PATH="$PATH:${HOME}/.dotnet/tools"

[[ -f "$BUILD_DIR/beskid.exe" ]] || { echo "Missing $BUILD_DIR/beskid.exe" >&2; exit 1; }
[[ -f "$BUILD_DIR/beskid_lsp.exe" ]] || { echo "Missing $BUILD_DIR/beskid_lsp.exe" >&2; exit 1; }

out="beskid-${VERSION}-windows-amd64.msi"

wix build \
  "${DISTRIB_ROOT}/windows/beskid.wxs" \
  -d Version="${VERSION}" \
  -d BuildDir="${BUILD_DIR}" \
  -d AssetsDir="${ASSETS_DIR}" \
  -o "${out}"

echo "built ${out}"
