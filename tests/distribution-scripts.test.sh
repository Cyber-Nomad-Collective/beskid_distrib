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
    if [[ -n "${FAKE_ASSET_FILE:-}" ]]; then sha256sum "${FAKE_ASSET_FILE}" | awk '{print $1}'
    else printf '%s' "${asset_content}" | sha256sum | awk '{print $1}'; fi
  else
    if [[ -n "${FAKE_ASSET_FILE:-}" ]]; then shasum -a 256 "${FAKE_ASSET_FILE}" | awk '{print $1}'
    else printf '%s' "${asset_content}" | shasum -a 256 | awk '{print $1}'; fi
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
    if [[ -n "${FAKE_ASSET_FILE:-}" ]]; then cp "${FAKE_ASSET_FILE}" "${output_dir}/${pattern}"
    else printf '%s' "${asset_content}" >"${output_dir}/${pattern}"; fi
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

# Distribution adapters consume the complete compiler-owned target bundle.
# Extraction validates the exact release identity and required no-env prefix
# layout before making any files visible at the destination.
bundle_root="${tmp}/bundle-source/beskid-0.4.481-x86_64-unknown-linux-gnu"
mkdir -p \
  "${bundle_root}/bin" \
  "${bundle_root}/lib/beskid-runtime/abi-5/x86_64-unknown-linux-gnu/release" \
  "${bundle_root}/beskid_corelib" \
  "${bundle_root}/packages/foundation"
printf 'cli' >"${bundle_root}/bin/beskid"
printf 'lsp' >"${bundle_root}/bin/beskid_lsp"
printf 'updater' >"${bundle_root}/bin/beskid-up"
printf '{}\n' >"${bundle_root}/lib/beskid-runtime/abi-5/x86_64-unknown-linux-gnu/release/abi.json"
printf 'project { name = "corelib" }\n' >"${bundle_root}/beskid_corelib/corelib.bproj"
printf 'project { name = "corelib_foundation" }\n' >"${bundle_root}/packages/foundation/corelib_foundation.bproj"
printf '0.4.481\n' >"${bundle_root}/release-version.txt"
tar -C "${tmp}/bundle-source" -czf "${tmp}/valid-bundle.tar.gz" "$(basename "${bundle_root}")"

PATH="${tmp}/bin:${PATH}" FAKE_GH_LOG="${tmp}/gh.log" \
  FAKE_RELEASE_VERSION=0.4.481 \
  FAKE_EXPECTED_ASSET=beskid-x86_64-unknown-linux-gnu.tar.gz \
  FAKE_ASSET_FILE="${tmp}/valid-bundle.tar.gz" GH_TOKEN=test \
  bash "${root}/scripts/fetch-release-bundle.sh" \
    0.4.481 x86_64-unknown-linux-gnu "${tmp}/fetched-bundle"
[[ -f "${tmp}/fetched-bundle/beskid_corelib/corelib.bproj" ]] || \
  fail 'verified bundle fetch did not expose the complete target bundle'
grep -Fq 'release download v0.4.481' "${tmp}/gh.log" || \
  fail 'bundle fetch did not use the immutable complete-bundle release'

bash "${root}/scripts/extract-release-bundle.sh" \
  "${tmp}/valid-bundle.tar.gz" 0.4.481 x86_64-unknown-linux-gnu "${tmp}/extracted"
for required in \
  bin/beskid bin/beskid_lsp bin/beskid-up \
  lib/beskid-runtime/abi-5/x86_64-unknown-linux-gnu/release/abi.json \
  beskid_corelib/corelib.bproj packages/foundation/corelib_foundation.bproj \
  release-version.txt; do
  [[ -f "${tmp}/extracted/${required}" ]] || fail "bundle extraction omitted ${required}"
done

cp "${tmp}/valid-bundle.tar.gz" "${tmp}/invalid-bundle.tar.gz"
printf '0.4.999\n' >"${bundle_root}/release-version.txt"
tar -C "${tmp}/bundle-source" -czf "${tmp}/invalid-bundle.tar.gz" "$(basename "${bundle_root}")"
if bash "${root}/scripts/extract-release-bundle.sh" \
  "${tmp}/invalid-bundle.tar.gz" 0.4.481 x86_64-unknown-linux-gnu "${tmp}/rejected"; then
  fail 'bundle extraction accepted a mismatched release-version marker'
fi
[[ ! -e "${tmp}/rejected" ]] || fail 'invalid bundle escaped its extraction staging directory'

# A verified checksum authenticates bytes, not archive topology. Reject links
# before extraction so a malformed release bundle cannot write through a link
# outside the atomic staging directory.
printf '0.4.481\n' >"${bundle_root}/release-version.txt"
ln -s /tmp "${bundle_root}/packages/escape-link"
tar -C "${tmp}/bundle-source" -czf "${tmp}/linked-bundle.tar.gz" "$(basename "${bundle_root}")"
if bash "${root}/scripts/extract-release-bundle.sh" \
  "${tmp}/linked-bundle.tar.gz" 0.4.481 x86_64-unknown-linux-gnu "${tmp}/linked-rejected"; then
  fail 'bundle extraction accepted a symbolic link'
fi
[[ ! -e "${tmp}/linked-rejected" ]] || fail 'linked bundle escaped extraction staging'
rm "${bundle_root}/packages/escape-link"

mkdir -p \
  "${tmp}/windows-build/bin" \
  "${tmp}/windows-build/lib/beskid-runtime/abi-5/x86_64-pc-windows-msvc/release" \
  "${tmp}/windows-build/beskid_corelib" \
  "${tmp}/windows-build/packages"
: >"${tmp}/windows-build/bin/beskid.exe"
: >"${tmp}/windows-build/bin/beskid_lsp.exe"
: >"${tmp}/windows-build/bin/beskid-up.exe"
: >"${tmp}/windows-build/lib/beskid-runtime/abi-5/x86_64-pc-windows-msvc/release/abi.json"
: >"${tmp}/windows-build/beskid_corelib/corelib.bproj"

node "${root}/windows/render-bundle-fragment.mjs" \
  "${tmp}/windows-build" "${tmp}/windows-build/bundle-files.wxs"
grep -Fq 'ComponentGroup Id="BundleFiles"' "${tmp}/windows-build/bundle-files.wxs" || \
  fail 'Windows bundle fragment omitted its component group'
grep -Fq 'Name="beskid.exe"' "${tmp}/windows-build/bundle-files.wxs" || \
  fail 'Windows bundle fragment omitted the CLI'
grep -Fq 'Name="abi.json"' "${tmp}/windows-build/bundle-files.wxs" || \
  fail 'Windows bundle fragment omitted the runtime kit'
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
