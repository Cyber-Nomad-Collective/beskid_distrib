#!/usr/bin/env bash
# Map a Rust target triple + stream to a release asset name.
#
# Usage: source target-map.sh
#        target_asset_name <stream> <target>
#
#   stream  cli | lsp
#   target  x86_64-unknown-linux-gnu | aarch64-apple-darwin | x86_64-pc-windows-msvc
#
# Echoes the asset name to stdout.
#
# Mapping (consistent with compiler workflow build-release-artifact.sh):
#   x86_64-unknown-linux-gnu   → beskid-linux-amd64        (cli)
#                                beskid_lsp-linux-amd64    (lsp)
#   aarch64-apple-darwin       → beskid-darwin-arm64        (cli)
#                                beskid_lsp-darwin-arm64    (lsp)
#   x86_64-pc-windows-msvc     → beskid-windows-amd64.exe   (cli)
#                                beskid_lsp-windows-amd64.exe (lsp)
set -euo pipefail

target_asset_name() {
  local stream="${1:?stream (cli | lsp)}"
  local target="${2:?target triple}"

  case "${stream}" in
    cli) local prefix="beskid" ;;
    lsp) local prefix="beskid_lsp" ;;
    *) echo "Unsupported stream: ${stream}" >&2; return 1 ;;
  esac

  case "${target}" in
    x86_64-unknown-linux-gnu) echo "${prefix}-linux-amd64" ;;
    aarch64-apple-darwin)     echo "${prefix}-darwin-arm64" ;;
    x86_64-pc-windows-msvc)   echo "${prefix}-windows-amd64.exe" ;;
    *) echo "Unsupported target: ${target}" >&2; return 1 ;;
  esac
}
