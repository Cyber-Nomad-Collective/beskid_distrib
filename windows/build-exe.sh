#!/usr/bin/env bash
# Build a WiX Burn EXE bootstrapper which installs the Beskid MSI.
# Usage: build-exe.sh <version> <msi-path> <assets-dir>
set -euo pipefail

VERSION="${1:?version (SemVer)}"
MSI_PATH="${2:?MSI path}"
ASSETS_DIR="${3:?assets directory}"
DISTRIB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../scripts/version.sh
source "${DISTRIB_ROOT}/scripts/version.sh"
# shellcheck source=../scripts/wix-toolchain.sh
source "${DISTRIB_ROOT}/scripts/wix-toolchain.sh"

validate_distribution_version "${VERSION}"
WINDOWS_VERSION="$(windows_installer_version "${VERSION}")"

[[ -f "${MSI_PATH}" ]] || { echo "Missing ${MSI_PATH}" >&2; exit 1; }
[[ -f "${ASSETS_DIR}/icons/beskid-512.png" ]] || { echo "Missing bootstrapper logo" >&2; exit 1; }

load_wix_extension WixToolset.Bal.wixext

out="beskid-${VERSION}-windows-amd64.exe"
wix build "${DISTRIB_ROOT}/windows/beskid.bundle.wxs" \
  -ext "WixToolset.Bal.wixext/${BESKID_WIX_VERSION}" \
  -d Version="${WINDOWS_VERSION}" \
  -d MsiPath="${MSI_PATH}" \
  -d AssetsDir="${ASSETS_DIR}" \
  -o "${out}"

echo "built ${out}"
