#!/usr/bin/env bash
# Resolve the rolling release version + compiler SHA from beskid_compiler.
#
# Reads cli-version.txt from the configured rolling CLI release. The
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

ROLLING_TAG="${CLI_ROLLING_TAG:-cli-stable}"

if [[ "${ROLLING_TAG}" != cli-stable && "${ROLLING_TAG}" != cli-unstable ]]; then
  echo "Unsupported CLI rolling tag: ${ROLLING_TAG}" >&2
  exit 1
fi

gh release download "$ROLLING_TAG" --repo "$REPO" --pattern "cli-version.txt" --dir "$tmp" --clobber

[[ -f "$tmp/cli-version.txt" ]] || { echo "cli-version.txt not found on ${ROLLING_TAG}" >&2; exit 1; }
version="$(tr -d '[:space:]' < "$tmp/cli-version.txt")"
# Fail closed: distribution may only consume the compiler-minted global SemVer.
[[ "${version}" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || {
  echo "${ROLLING_TAG} cli-version.txt is absent or not strict X.Y.Z semver: ${version:-<empty>}" >&2
  exit 1
}
printf '%s' "${version}"
