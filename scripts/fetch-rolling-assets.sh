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
# Maps a Rust target triple to the release asset name produced by the compiler
# workflow (see superrepo scripts/ci/build-release-artifact.sh):
#   x86_64-unknown-linux-gnu   -> beskid-linux-amd64       (cli)
#                                  beskid_lsp-linux-amd64   (lsp)
#   aarch64-apple-darwin       -> beskid-darwin-arm64       (cli)
#                                  beskid_lsp-darwin-arm64   (lsp)
#   x86_64-pc-windows-msvc     -> beskid-windows-amd64.exe  (cli)
#                                  beskid_lsp-windows-amd64.exe (lsp)
set -euo pipefail

STREAM="${1:?stream (cli | lsp)}"
TARGET="${2:?target triple}"
OUT_NAME="${3:-}"

REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"

case "$STREAM" in
  cli) prefix="beskid" ;;
  lsp) prefix="beskid_lsp" ;;
  *) echo "Unsupported stream: $STREAM" >&2; exit 1 ;;
esac

case "$TARGET" in
  x86_64-unknown-linux-gnu) asset="${prefix}-linux-amd64" ;;
  aarch64-apple-darwin)     asset="${prefix}-darwin-arm64" ;;
  x86_64-pc-windows-msvc)   asset="${prefix}-windows-amd64.exe" ;;
  *) echo "Unsupported target: $TARGET" >&2; exit 1 ;;
esac

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
