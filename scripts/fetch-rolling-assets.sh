#!/usr/bin/env bash
# Fetch the rolling CLI/LSP release assets for one or more
# targets from Cyber-Nomad-Collective/beskid_compiler into the caller's CWD.
#
# Usage: fetch-rolling-assets.sh <stream> <target> [<out-name>]
#   stream   cli | lsp
#   target   x86_64-unknown-linux-gnu | aarch64-apple-darwin | x86_64-pc-windows-msvc
#   out-name optional output filename (defaults to the release asset name)
#
# Env: GH_TOKEN (read access on Cyber-Nomad-Collective/beskid_compiler)
#
# Target→asset mapping is in target-map.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
source "${ROOT}/target-map.sh"
# shellcheck source=release-asset-authority.sh
source "${ROOT}/release-asset-authority.sh"

STREAM="${1:?stream (cli | lsp)}"
TARGET="${2:?target triple}"
OUT_NAME="${3:-}"

REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"
CHANNEL="${BESKID_RELEASE_CHANNEL:-stable}"
ROLLING_TAG="${CLI_ROLLING_TAG:-}"

asset="$(target_asset_name "${STREAM}" "${TARGET}")"
if [[ -z "$ROLLING_TAG" ]]; then
  case "$CHANNEL" in
    stable|unstable) ;;
    *) echo "Unsupported release channel: ${CHANNEL}" >&2; exit 1 ;;
  esac
  ROLLING_TAG="${STREAM}-${CHANNEL}"
fi

tag="$ROLLING_TAG"

echo "Fetching ${asset} from ${REPO}@${tag}..."
destination="${OUT_NAME:-${asset}}"
fetch_verified_release_asset "${REPO}" "${tag}" "" "${asset}" "${destination}"

if [[ "${destination}" != "${asset}" ]]; then
  echo "Saved as ${OUT_NAME}"
else
  echo "Saved ${asset}"
fi
