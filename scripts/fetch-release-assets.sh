#!/usr/bin/env bash
# Fetch one CLI or LSP asset from its immutable versioned GitHub release.
#
# Usage: fetch-release-assets.sh <stream> <version> <target> [<out-name>]
#   stream   cli | lsp
#   version  bare SemVer used to address <stream>-v<version>
#   target   x86_64-unknown-linux-gnu | aarch64-apple-darwin | x86_64-pc-windows-msvc
#
# Env: GH_TOKEN (read access on Cyber-Nomad-Collective/beskid_compiler)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "${ROOT}/target-map.sh"

STREAM="${1:?stream (cli | lsp)}"
VERSION="${2:?version (SemVer)}"
TARGET="${3:?target triple}"
OUT_NAME="${4:-}"

REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"

[[ "${VERSION}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "version must be bare SemVer: ${VERSION}" >&2
  exit 1
}

asset="$(target_asset_name "${STREAM}" "${TARGET}")"
tag="${STREAM}-v${VERSION}"
echo "Fetching ${asset} from ${REPO}@${tag}..."
gh release download "${tag}" --repo "${REPO}" --pattern "${asset}" --clobber

if [[ -n "${OUT_NAME}" && "${OUT_NAME}" != "${asset}" ]]; then
  mv -f "${asset}" "${OUT_NAME}"
  echo "Saved as ${OUT_NAME}"
else
  echo "Saved ${asset}"
fi
