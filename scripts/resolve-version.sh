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

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=version.sh
source "${ROOT}/version.sh"

REPO="Cyber-Nomad-Collective/beskid_compiler"
: "${GH_TOKEN:?GH_TOKEN must be exported (read on ${REPO})}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ROLLING_TAG="${CLI_ROLLING_TAG:-cli-stable}"

if [[ "${ROLLING_TAG}" != cli-stable && "${ROLLING_TAG}" != cli-unstable ]]; then
  echo "Unsupported CLI rolling tag: ${ROLLING_TAG}" >&2
  exit 1
fi

resolve_version_from_tag() {
  local tag="$1"
  rm -rf "${tmp}/cli-version.txt"
  if gh release download "$tag" --repo "$REPO" --pattern "cli-version.txt" --dir "$tmp" --clobber; then
    if [[ -f "$tmp/cli-version.txt" ]]; then
      tr -d '[:space:]' < "$tmp/cli-version.txt"
      return 0
    fi
  fi
  return 1
}

version=''
if ! version="$(resolve_version_from_tag "${ROLLING_TAG}")"; then
  if [[ "${ROLLING_TAG}" != "cli-unstable" ]]; then
    echo "cli-version.txt not found on ${ROLLING_TAG}" >&2
    exit 1
  fi
  echo "cli-unstable release not found; attempting stable fallback for version resolution" >&2
  version="$(resolve_version_from_tag "cli-stable")"
fi

[[ -n "${version}" ]] || { echo "cli-version.txt not found on ${ROLLING_TAG}" >&2; exit 1; }
# Fail closed: distribution may only consume the compiler-minted stable or
# exact unstable version shape.
validate_distribution_version "${version}"
printf '%s' "${version}"
