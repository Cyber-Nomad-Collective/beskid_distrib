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

# Every package must be built from an immutable, versioned compiler release;
# cli-latest is only an alias for discovery, never a packaging input.
assert_contains "${root}/scripts/fetch-release-assets.sh" 'tag="${STREAM}-v${VERSION}"'

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

printf 'Distribution static tests OK\n'
