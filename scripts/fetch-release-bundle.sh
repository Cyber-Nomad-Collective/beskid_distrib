#!/usr/bin/env bash
# Fetch, verify, and extract one immutable compiler target bundle.
#
# Usage: fetch-release-bundle.sh <version> <target> <destination>
# Env: GH_TOKEN (read access on Cyber-Nomad-Collective/beskid_compiler)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=version.sh
source "${ROOT}/version.sh"
# shellcheck source=release-asset-authority.sh
source "${ROOT}/release-asset-authority.sh"

VERSION="${1:?version (SemVer)}"
TARGET="${2:?target triple}"
DESTINATION="${3:?destination directory}"
REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"

validate_distribution_version "${VERSION}"
asset="beskid-${TARGET}.tar.gz"
tag="v${VERSION}"
staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

echo "Fetching ${asset} from ${REPO}@${tag}..."
fetch_verified_release_asset "${REPO}" "${tag}" "${VERSION}" "${asset}" "${staging}/${asset}"
bash "${ROOT}/extract-release-bundle.sh" "${staging}/${asset}" "${VERSION}" "${TARGET}" "${DESTINATION}"
