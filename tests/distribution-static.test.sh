#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
workflow="${root}/../.github/workflows/distribute.yml"

assert_contains() {
  local file="$1" needle="$2"
  if ! grep -Fq -- "$needle" "$file"; then
    echo "expected ${file} to contain: ${needle}" >&2
    exit 1
  fi
}

assert_file_exists() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    echo "expected file to exist: ${file}" >&2
    exit 1
  fi
}

# Every package must be built from an immutable, versioned compiler release;
# `cli-stable` and `cli-unstable` are discovery channels; package inputs must
# still come from immutable `cli-v*` tags.
assert_contains "${root}/scripts/fetch-release-assets.sh" 'tag="${STREAM}-v${VERSION}"'

# Shared target→asset mapping is extracted into a single sourced file.
assert_file_exists "${root}/scripts/target-map.sh"
assert_contains "${root}/scripts/fetch-release-assets.sh" 'source "${ROOT}/target-map.sh"'
assert_contains "${root}/scripts/fetch-rolling-assets.sh" 'source "${ROOT}/target-map.sh"'

# The Windows download is an EXE bootstrapper that chains the MSI.
assert_contains "${root}/windows/beskid.bundle.wxs" '<Bundle'
assert_contains "${root}/windows/beskid.bundle.wxs" '<MsiPackage SourceFile='

# macOS users receive an application-style DMG in addition to Homebrew.
assert_contains "${root}/macos/build-dmg.sh" 'hdiutil create'
assert_contains "${root}/macos/build-dmg.sh" 'beskid_lsp'

# Workflow publishes the new platform artifacts to the immutable release.
assert_contains "${workflow}" 'Build Windows EXE bootstrapper'
assert_contains "${workflow}" 'Build macOS DMG'
assert_contains "${workflow}" 'beskid-${VERSION}-windows-amd64.exe'
assert_contains "${workflow}" 'beskid-${VERSION}-macos-arm64.dmg'

# Workflow has 5 platform jobs (no AUR).
assert_contains "${workflow}" 'windows-msi:'
assert_contains "${workflow}" 'macos-brew:'
assert_contains "${workflow}" 'macos-dmg:'
assert_contains "${workflow}" 'ubuntu-deb:'
assert_contains "${workflow}" 'linux-snap:'

printf 'Distribution static tests OK\n'
