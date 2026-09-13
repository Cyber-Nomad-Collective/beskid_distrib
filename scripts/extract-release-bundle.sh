#!/usr/bin/env bash
# Validate and atomically extract one compiler-owned direct-install bundle.
#
# Usage: extract-release-bundle.sh <archive> <version> <target> <destination>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=version.sh
source "${ROOT}/version.sh"

ARCHIVE="${1:?bundle archive}"
VERSION="${2:?release version}"
TARGET="${3:?target triple}"
DESTINATION="${4:?destination directory}"

validate_distribution_version "${VERSION}"
case "${TARGET}" in
  x86_64-unknown-linux-gnu|aarch64-apple-darwin|x86_64-pc-windows-msvc) ;;
  *) echo "Unsupported release target: ${TARGET}" >&2; exit 1 ;;
esac
[[ -f "${ARCHIVE}" ]] || { echo "Missing bundle archive: ${ARCHIVE}" >&2; exit 1; }
[[ ! -e "${DESTINATION}" ]] || { echo "Bundle destination already exists: ${DESTINATION}" >&2; exit 1; }

expected_root="beskid-${VERSION}-${TARGET}"
parent="$(cd "$(dirname "${DESTINATION}")" && pwd)"
stage="$(mktemp -d "${parent}/.beskid-bundle.XXXXXX")"
trap 'rm -rf "${stage}"' EXIT

while IFS= read -r entry; do
  normalized="${entry%/}"
  case "${normalized}" in
    "${expected_root}"|"${expected_root}/"*) ;;
    *) echo "Bundle contains a path outside ${expected_root}: ${entry}" >&2; exit 1 ;;
  esac
  case "/${normalized}/" in
    */../*) echo "Bundle contains a parent traversal: ${entry}" >&2; exit 1 ;;
  esac
done < <(tar -tzf "${ARCHIVE}")

# Reject links and special files before extraction. A checksum authenticates
# the archive bytes, but links could otherwise redirect a later archive entry
# outside the staging root.
while IFS= read -r listing; do
  entry_type="${listing:0:1}"
  case "${entry_type}" in
    -|d) ;;
    *) echo "Bundle contains an unsupported linked or special entry: ${listing}" >&2; exit 1 ;;
  esac
done < <(tar -tvzf "${ARCHIVE}")

tar -xzf "${ARCHIVE}" -C "${stage}"
bundle="${stage}/${expected_root}"
[[ -d "${bundle}" ]] || { echo "Bundle omitted its exact root directory: ${expected_root}" >&2; exit 1; }

extension=""
[[ "${TARGET}" == x86_64-pc-windows-msvc ]] && extension=".exe"
for binary in beskid beskid_lsp beskid-up; do
  [[ -f "${bundle}/bin/${binary}${extension}" ]] || {
    echo "Bundle omitted bin/${binary}${extension}" >&2
    exit 1
  }
done
[[ -f "${bundle}/lib/beskid-runtime/abi-5/${TARGET}/release/abi.json" ]] || {
  echo "Bundle omitted the exact ABI-v5 release kit for ${TARGET}" >&2
  exit 1
}
[[ -f "${bundle}/beskid_corelib/corelib.bproj" ]] || { echo 'Bundle omitted corelib.' >&2; exit 1; }
[[ -d "${bundle}/packages" ]] || { echo 'Bundle omitted bundled packages.' >&2; exit 1; }
[[ -f "${bundle}/release-version.txt" ]] || { echo 'Bundle omitted release-version.txt.' >&2; exit 1; }
printf '%s\n' "${VERSION}" | cmp -s - "${bundle}/release-version.txt" || {
  echo 'Bundle release-version.txt does not match the requested version exactly.' >&2
  exit 1
}

chmod 0755 "${bundle}/bin/beskid${extension}" \
  "${bundle}/bin/beskid_lsp${extension}" \
  "${bundle}/bin/beskid-up${extension}"
mv "${bundle}" "${DESTINATION}"
echo "Extracted verified Beskid ${VERSION} bundle for ${TARGET} to ${DESTINATION}"
