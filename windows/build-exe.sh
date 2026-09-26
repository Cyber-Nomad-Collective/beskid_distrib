#!/usr/bin/env bash
# Build a WiX Burn EXE bootstrapper with pinned remote prerequisites.
# Usage: build-exe.sh <version> <msi-path> <assets-dir>
# Environment: BESKID_PREREQUISITES_LOCK (optional reviewed lock override)
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
[[ -s "${ASSETS_DIR}/icons/beskid.ico" ]] || { echo "Missing bootstrapper icon" >&2; exit 1; }
[[ -s "${DISTRIB_ROOT}/windows/beskid-theme.xml" && -s "${DISTRIB_ROOT}/windows/beskid-theme.wxl" ]] || { echo "Missing bootstrapper theme" >&2; exit 1; }

load_wix_extension WixToolset.Bal.wixext
load_wix_extension WixToolset.Util.wixext

fragment_dir="$(mktemp -d "${TMPDIR:-/tmp}/beskid-prerequisites.XXXXXX")"
trap 'rm -rf "${fragment_dir}"' EXIT
prerequisites_lock="${BESKID_PREREQUISITES_LOCK:-${DISTRIB_ROOT}/windows/prerequisites.lock.json}"
prerequisites_fragment="${fragment_dir}/prerequisites.wxs"
node "${DISTRIB_ROOT}/windows/render-prerequisites.mjs" "${prerequisites_lock}" "${prerequisites_fragment}"

out="beskid-${VERSION}-windows-amd64.exe"
wix build "${DISTRIB_ROOT}/windows/beskid.bundle.wxs" "${prerequisites_fragment}" \
  -ext "WixToolset.Bal.wixext/${BESKID_WIX_VERSION}" \
  -ext "WixToolset.Util.wixext/${BESKID_WIX_VERSION}" \
  -d Version="${WINDOWS_VERSION}" \
  -d MsiPath="${MSI_PATH}" \
  -d AssetsDir="${ASSETS_DIR}" \
  -d DistribRoot="${DISTRIB_ROOT}" \
  -o "${out}"

echo "built ${out}"
