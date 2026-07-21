#!/usr/bin/env bash
# Resolve the rolling release version + compiler SHA from beskid_compiler.
#
# Reads the cli-version.txt asset attached to the cli-latest release. The
# compiler workflow (superrepo scripts/ci/publish-release-stream.sh) writes
# this file when it uploads the rolling release.
#
# Usage: resolve-version.sh
# Env: GH_TOKEN (read access on Cyber-Nomad-Collective/beskid_compiler)
# Prints "<version>" on stdout. Also exports the compiler SHA by reading the
# release's target_commitish.
set -euo pipefail

REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gh release download cli-latest --repo "$REPO" --pattern "cli-version.txt" --dir "$tmp" --clobber

[[ -f "$tmp/cli-version.txt" ]] || { echo "cli-version.txt not found on cli-latest" >&2; exit 1; }
version="$(tr -d '[:space:]' < "$tmp/cli-version.txt")"
# Fail closed: distribution may only consume the compiler-minted global SemVer.
[[ "${version}" =~ ^0\.4\.(0|[1-9][0-9]*)$ ]] || {
  echo "cli-latest cli-version.txt is absent or not strict 0.4.<build>: ${version:-<empty>}" >&2
  exit 1
}
printf '%s' "${version}"
