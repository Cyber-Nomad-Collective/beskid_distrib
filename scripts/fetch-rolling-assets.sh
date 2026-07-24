#!/usr/bin/env bash
# Fetch the rolling cli-latest / lsp-latest release assets for one or more
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

STREAM="${1:?stream (cli | lsp)}"
TARGET="${2:?target triple}"
OUT_NAME="${3:-}"

REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"

asset="$(target_asset_name "${STREAM}" "${TARGET}")"
tag="cli-latest"
[[ "$STREAM" == "lsp" ]] && tag="lsp-latest"

echo "Fetching ${asset} from ${REPO}@${tag}..."
gh release download "$tag" --repo "$REPO" --pattern "$asset" --clobber

if [[ -n "$OUT_NAME" && "$OUT_NAME" != "$asset" ]]; then
  mv -f "$asset" "$OUT_NAME"
  echo "Saved as ${OUT_NAME}"
else
  echo "Saved ${asset}"
fi
