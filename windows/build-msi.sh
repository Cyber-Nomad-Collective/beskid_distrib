#!/usr/bin/env bash
# Build the Beskid Windows MSI with WiX v4.
#
# Ensures the pinned WiX v4 CLI and UI extension are available, then runs
# `wix build` against beskid.wxs with the numeric installer version plus the
# build/assets directories passed as WiX variables.
#
# Usage: build-msi.sh <version> <build-dir> <assets-dir>
#   version    resolved release version (e.g. 0.4.0 or 0.4.1-unstable)
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
# shellcheck source=../scripts/version.sh
source "${DISTRIB_ROOT}/scripts/version.sh"
# shellcheck source=../scripts/wix-toolchain.sh
source "${DISTRIB_ROOT}/scripts/wix-toolchain.sh"

validate_distribution_version "${VERSION}"
WINDOWS_VERSION="$(windows_installer_version "${VERSION}")"

load_wix_extension WixToolset.UI.wixext

[[ -f "$BUILD_DIR/beskid.exe" ]] || { echo "Missing $BUILD_DIR/beskid.exe" >&2; exit 1; }
[[ -f "$BUILD_DIR/beskid_lsp.exe" ]] || { echo "Missing $BUILD_DIR/beskid_lsp.exe" >&2; exit 1; }
[[ -s "$ASSETS_DIR/icons/beskid.ico" ]] || { echo "Missing $ASSETS_DIR/icons/beskid.ico" >&2; exit 1; }

out="beskid-${VERSION}-windows-amd64.msi"

wix build \
  "${DISTRIB_ROOT}/windows/beskid.wxs" \
  -ext "WixToolset.UI.wixext/${BESKID_WIX_VERSION}" \
  -d Version="${WINDOWS_VERSION}" \
  -d BuildDir="${BUILD_DIR}" \
  -d AssetsDir="${ASSETS_DIR}" \
  -o "${out}"

echo "built ${out}"
