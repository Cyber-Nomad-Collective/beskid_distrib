#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Stable and unstable releases share one validator. The public prerelease
# identity remains intact, while Windows installer metadata receives the
# numeric form required by MSI and Burn.
# shellcheck source=../scripts/version.sh
source "${root}/scripts/version.sh"
validate_distribution_version '0.4.481'
validate_distribution_version '0.4.481-unstable'
if validate_distribution_version '0.4.481-preview'; then
  fail 'unsupported prerelease suffix was accepted'
fi
[[ "$(windows_installer_version '0.4.481')" == '0.4.481' ]] || \
  fail 'stable Windows version projection changed the public version'
[[ "$(windows_installer_version '0.4.481-unstable')" == '0.4.481' ]] || \
  fail 'unstable Windows version projection was not numeric'

mkdir -p "${tmp}/bin" "${tmp}/fetch" "${tmp}/windows-build" "${tmp}/assets/icons"
cat >"${tmp}/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${FAKE_GH_LOG}"
asset_content="${FAKE_ASSET_CONTENT:-verified compiler asset}"
asset_name="${FAKE_EXPECTED_ASSET:-beskid-linux-amd64}"
asset_digest() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "${asset_content}" | sha256sum | awk '{print $1}'
  else
    printf '%s' "${asset_content}" | shasum -a 256 | awk '{print $1}'
  fi
}
if [[ "$1" == 'api' ]]; then
  printf '{"assets":[{"name":"%s","digest":"sha256:%s"}]}\n' \
    "${asset_name}" "${FAKE_ASSET_DIGEST:-$(asset_digest)}"
  exit 0
fi
if [[ "$1 $2" == 'release download' ]]; then
  if [[ "${FAKE_UNSTABLE_MISSING:-false}" == 'true' && "$3" == 'cli-unstable' ]]; then
    exit 1
  fi
  output_dir='.'
  pattern=''
  for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == '--dir' ]]; then
      next=$((i + 1))
      output_dir="${!next}"
    elif [[ "${!i}" == '--pattern' ]]; then
      next=$((i + 1))
      pattern="${!next}"
    fi
  done
  mkdir -p "${output_dir}"
  if [[ "${pattern}" == 'release-state.json' ]]; then
    [[ "${FAKE_MANIFEST_MODE:-valid}" != 'missing' ]] || exit 1
    manifest_version="${FAKE_RELEASE_VERSION}"
    [[ "${FAKE_MANIFEST_MODE:-valid}" != 'wrong-version' ]] || manifest_version='0.4.999'
    manifest_asset="${asset_name}"
    [[ "${FAKE_MANIFEST_MODE:-valid}" != 'missing-asset' ]] || manifest_asset='different-asset'
    printf '{"schema_version":1,"version":"%s","publishable":true,"available_artifacts":["%s"]}\n' \
      "${manifest_version}" "${manifest_asset}" >"${output_dir}/${pattern}"
  elif [[ "${pattern}" == 'cli-version.txt' ]]; then
    printf '%s\n' "${FAKE_RELEASE_VERSION}" >"${output_dir}/${pattern}"
  else
    printf '%s' "${asset_content}" >"${output_dir}/${pattern}"
  fi
fi
SH

cat >"${tmp}/bin/dotnet" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'dotnet %s\n' "$*" >>"${FAKE_WIX_LOG}"
SH

cat >"${tmp}/bin/wix" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'wix %s\n' "$*" >>"${FAKE_WIX_LOG}"
if [[ "$1" == '--version' ]]; then
  printf '7.0.0\n'
  exit 0
fi
if [[ "$1" == 'build' ]]; then
  for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == '-o' ]]; then
      next=$((i + 1))
      : >"${!next}"
      exit 0
    fi
  done
fi
SH
chmod +x "${tmp}/bin/gh" "${tmp}/bin/dotnet" "${tmp}/bin/wix"

# Immutable asset fetch must accept the exact prerelease identity emitted by
# Compiler release and address the matching immutable tag.
(
  cd "${tmp}/fetch"
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.481-unstable GH_TOKEN=test \
    bash "${root}/scripts/fetch-release-assets.sh" \
      cli 0.4.481-unstable x86_64-unknown-linux-gnu
)
[[ -f "${tmp}/fetch/beskid-linux-amd64" ]] || fail 'unstable CLI asset was not fetched'
[[ "$(cat "${tmp}/fetch/beskid-linux-amd64")" == 'verified compiler asset' ]] || \
  fail 'verified CLI asset contents changed during fetch'
grep -Fq 'release download cli-v0.4.481-unstable' "${tmp}/gh.log" || \
  fail 'unstable immutable tag identity was changed during fetch'
grep -Fq -- '--pattern release-state.json' "${tmp}/gh.log" || \
  fail 'immutable fetch did not require release-state manifest authority'
grep -Fq 'api repos/Cyber-Nomad-Collective/beskid_compiler/releases/tags/cli-v0.4.481-unstable' \
  "${tmp}/gh.log" || fail 'immutable fetch did not read the release asset checksum authority'

rm -f "${tmp}/fetch/beskid-linux-amd64"
if (
  cd "${tmp}/fetch"
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.481-unstable FAKE_MANIFEST_MODE=missing GH_TOKEN=test \
    bash "${root}/scripts/fetch-release-assets.sh" \
      cli 0.4.481-unstable x86_64-unknown-linux-gnu
); then
  fail 'immutable fetch accepted a missing release-state manifest'
fi
[[ ! -e "${tmp}/fetch/beskid-linux-amd64" ]] || fail 'unverified asset escaped after missing manifest'

if (
  cd "${tmp}/fetch"
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.481-unstable FAKE_MANIFEST_MODE=wrong-version GH_TOKEN=test \
    bash "${root}/scripts/fetch-release-assets.sh" \
      cli 0.4.481-unstable x86_64-unknown-linux-gnu
); then
  fail 'immutable fetch accepted a manifest for a different version'
fi
[[ ! -e "${tmp}/fetch/beskid-linux-amd64" ]] || fail 'wrong-version asset escaped staging'

if (
  cd "${tmp}/fetch"
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.481-unstable \
    FAKE_ASSET_DIGEST=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
    GH_TOKEN=test bash "${root}/scripts/fetch-release-assets.sh" \
      cli 0.4.481-unstable x86_64-unknown-linux-gnu
); then
  fail 'immutable fetch accepted an asset with a mismatched checksum'
fi
[[ ! -e "${tmp}/fetch/beskid-linux-amd64" ]] || fail 'checksum-mismatched asset escaped staging'

mkdir -p "${tmp}/rolling"
(
  cd "${tmp}/rolling"
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.481-unstable GH_TOKEN=test CLI_ROLLING_TAG=cli-unstable \
    bash "${root}/scripts/fetch-rolling-assets.sh" cli x86_64-unknown-linux-gnu
)
[[ "$(cat "${tmp}/rolling/beskid-linux-amd64")" == 'verified compiler asset' ]] || \
  fail 'rolling fetch did not publish its verified asset'

# Manual unstable resolution must accept the same version read from the rolling
# release rather than rejecting the compiler-owned prerelease suffix.
resolved="$({
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.481-unstable GH_TOKEN=test CLI_ROLLING_TAG=cli-unstable \
    bash "${root}/scripts/resolve-version.sh"
})"
[[ "${resolved}" == '0.4.481-unstable' ]] || fail "unexpected unstable version: ${resolved}"

fallback="$({
  PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
    FAKE_RELEASE_VERSION=0.4.480 FAKE_UNSTABLE_MISSING=true \
    GH_TOKEN=test CLI_ROLLING_TAG=cli-unstable \
    bash "${root}/scripts/resolve-version.sh"
})"
[[ "${fallback}" == '0.4.480' ]] || fail "unstable rolling fallback did not resolve stable: ${fallback}"

: >"${tmp}/windows-build/beskid.exe"
: >"${tmp}/windows-build/beskid_lsp.exe"
printf 'ico' >"${tmp}/assets/icons/beskid.ico"
printf 'png' >"${tmp}/assets/icons/beskid-512.png"

# WiX inputs are externally observable installer metadata. The filenames keep
# the public prerelease identity while WiX receives a deterministic numeric
# version and explicitly loaded, version-matched extensions.
(
  cd "${tmp}"
  PATH="${tmp}/bin:${PATH}" FAKE_WIX_LOG="${tmp}/wix.log" \
    bash "${root}/windows/build-msi.sh" \
      0.4.481-unstable "${tmp}/windows-build" "${tmp}/assets"
  PATH="${tmp}/bin:${PATH}" FAKE_WIX_LOG="${tmp}/wix.log" \
    bash "${root}/windows/build-exe.sh" \
      0.4.481-unstable "${tmp}/beskid-0.4.481-unstable-windows-amd64.msi" "${tmp}/assets"
)
[[ -f "${tmp}/beskid-0.4.481-unstable-windows-amd64.exe" ]] || \
  fail 'Windows bootstrapper filename lost the public prerelease identity'
grep -Fq 'dotnet tool update --global wix --version 4.0.6' "${tmp}/wix.log" || \
  fail 'an ambient WiX tool is not replaced with the pinned version'
grep -Fq 'wix extension add -g WixToolset.UI.wixext/4.0.6' "${tmp}/wix.log" || \
  fail 'WiX UI extension is not installed at the toolchain version'
grep -Fq 'wix extension add -g WixToolset.Bal.wixext/4.0.6' "${tmp}/wix.log" || \
  fail 'WiX Burn extension is not installed at the toolchain version'
grep -Fq -- '-d Version=0.4.481 ' "${tmp}/wix.log" || \
  fail 'WiX did not receive the numeric unstable version projection'
grep -Fq -- "-d DistribRoot=${root}" "${tmp}/wix.log" || \
  fail 'WiX did not receive the distribution license source directory'
if grep -Fq -- '-d Version=0.4.481-unstable' "${tmp}/wix.log"; then
  fail 'WiX received the public prerelease string as installer metadata'
fi

printf 'Distribution script behavior tests OK\n'
