#!/usr/bin/env bash
# Build the Beskid Windows MSI with WiX v4.
#
# Ensures the pinned WiX v4 CLI and UI extension are available, then runs
# `wix build` against beskid.wxs with the numeric installer version plus the
# build/assets directories passed as WiX variables.
#
# Usage: build-msi.sh <version> <build-dir> <assets-dir>
#   version    resolved release version (e.g. 0.4.0 or 0.4.1-unstable)
#   build-dir  verified target bundle root (bin + ABI-v5 lib + corelib/packages)
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
command -v node >/dev/null 2>&1 || { echo "Node.js is required to render the WiX bundle fragment" >&2; exit 1; }

[[ -f "$BUILD_DIR/bin/beskid.exe" ]] || { echo "Missing $BUILD_DIR/bin/beskid.exe" >&2; exit 1; }
[[ -f "$BUILD_DIR/bin/beskid_lsp.exe" ]] || { echo "Missing $BUILD_DIR/bin/beskid_lsp.exe" >&2; exit 1; }
[[ -f "$BUILD_DIR/bin/beskid-up.exe" ]] || { echo "Missing $BUILD_DIR/bin/beskid-up.exe" >&2; exit 1; }
[[ -d "$BUILD_DIR/lib/beskid-runtime/abi-5" ]] || { echo "Missing ABI-v5 runtime kit" >&2; exit 1; }
[[ -f "$BUILD_DIR/beskid_corelib/corelib.bproj" ]] || { echo "Missing bundled corelib" >&2; exit 1; }
[[ -d "$BUILD_DIR/packages" ]] || { echo "Missing bundled packages" >&2; exit 1; }
[[ -s "$ASSETS_DIR/icons/beskid.ico" ]] || { echo "Missing $ASSETS_DIR/icons/beskid.ico" >&2; exit 1; }

out="beskid-${VERSION}-windows-amd64.msi"
fragment="$(mktemp "${TMPDIR:-/tmp}/beskid-bundle-files.XXXXXX.wxs")"
trap 'rm -f "${fragment}"' EXIT
node "${DISTRIB_ROOT}/windows/render-bundle-fragment.mjs" "${BUILD_DIR}" "${fragment}"

wix build \
  "${DISTRIB_ROOT}/windows/beskid.wxs" \
  "${fragment}" \
  -ext "WixToolset.UI.wixext/${BESKID_WIX_VERSION}" \
  -d Version="${WINDOWS_VERSION}" \
  -d BuildDir="${BUILD_DIR}" \
  -d AssetsDir="${ASSETS_DIR}" \
  -d DistribRoot="${DISTRIB_ROOT}" \
  -o "${out}"

echo "built ${out}"
