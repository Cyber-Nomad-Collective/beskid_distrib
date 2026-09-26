#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
ci="${root}/../scripts/ci"
workflows="${root}/../.woodpecker"
packager="${ci}/woodpecker-package-platform.mjs"
publisher="${ci}/woodpecker-release.sh"

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

# Every distribution surface consumes the compiler-owned complete target
# bundle through one fail-closed extraction seam.
assert_file_exists "${root}/scripts/fetch-release-bundle.sh"
assert_file_exists "${root}/scripts/extract-release-bundle.sh"
assert_contains "${root}/scripts/fetch-release-bundle.sh" 'source "${ROOT}/release-asset-authority.sh"'
assert_contains "${root}/scripts/fetch-release-bundle.sh" 'tag="v${VERSION}"'
assert_contains "${root}/scripts/fetch-release-bundle.sh" 'extract-release-bundle.sh'
assert_file_exists "${root}/windows/render-bundle-fragment.mjs"
assert_contains "${root}/windows/build-msi.sh" 'render-bundle-fragment.mjs'
assert_contains "${root}/windows/beskid.wxs" '<ComponentGroupRef Id='
assert_contains "${root}/macos/build-dmg.sh" 'cp -a "${BUILD_DIR}/." "${toolchain}/"'
assert_contains "${root}/deb/build-deb.sh" 'cp -a "${BUILD_DIR}/lib" "${PKGROOT}/usr/lib"'
assert_contains "${root}/deb/build-deb.sh" 'cp -a "${BUILD_DIR}/beskid_corelib" "${PKGROOT}/usr/beskid_corelib"'
assert_contains "${root}/deb/build-deb.sh" 'cp -a "${BUILD_DIR}/packages" "${PKGROOT}/usr/packages"'
assert_contains "${root}/macos/Formula/beskid.rb.tpl" 'libexec.install "bin", "lib", "beskid_corelib", "packages", "release-version.txt"'
assert_contains "${root}/docker/Dockerfile" 'COPY oci-build/beskid-bundle/ /opt/beskid/'
assert_contains "${root}/docker/Dockerfile.runner" 'COPY --from=beskid-base /opt/beskid /opt/beskid'

# The Windows download is an EXE bootstrapper that chains the MSI.
assert_contains "${root}/windows/beskid.bundle.wxs" '<Bundle'
assert_contains "${root}/windows/beskid.bundle.wxs" '<MsiPackage SourceFile='
assert_contains "${root}/windows/beskid.bundle.wxs" "LicenseUrl='https://www.apache.org/licenses/LICENSE-2.0'"
assert_contains "${root}/windows/beskid.wxs" 'xmlns:ui='
assert_contains "${root}/windows/beskid.wxs" '<ui:WixUI'
assert_contains "${root}/windows/beskid.wxs" 'DistribRoot)\LICENSE'

# macOS users receive an application-style DMG in addition to Homebrew.
assert_contains "${root}/macos/build-dmg.sh" 'dmgbuild.build_dmg'
assert_contains "${root}/macos/build-dmg.sh" 'beskid_lsp'
assert_contains "${root}/macos/build-dmg.sh" 'NOTICE.txt'
assert_file_exists "${root}/assets/dmg-background.png"
assert_contains "${root}/macos/build-dmg.sh" 'background.png'
assert_contains "${root}/macos/build-dmg.sh" 'dmgbuild==1.6.5'
assert_contains "${root}/macos/build-dmg.sh" 'dmgbuild.build_dmg'
assert_contains "${root}/macos/build-dmg.sh" 'icon_locations = {'
assert_contains "${root}/macos/build-dmg.sh" 'Applications'
assert_contains "${root}/macos/build-dmg.sh" 'volume_label="Beskid ${VERSION}"'

# Every supported package surface declares and carries the Apache-2.0 license.
assert_file_exists "${root}/LICENSE"
assert_file_exists "${root}/NOTICE"
assert_contains "${root}/macos/Formula/beskid.rb.tpl" 'license "Apache-2.0"'
assert_contains "${root}/docker/Dockerfile" 'org.opencontainers.image.licenses="Apache-2.0"'
assert_contains "${root}/docker/Dockerfile.runner" 'org.opencontainers.image.licenses="Apache-2.0"'
assert_contains "${root}/deb/build-deb.sh" '/usr/share/doc/beskid/copyright'

# Woodpecker native workers package verified bundles; release publication has
# one separate, explicitly enabled authority. OCI recipes remain checked above.
assert_file_exists "${packager}"
assert_file_exists "${publisher}"
for platform in linux macos windows; do
  assert_contains "${workflows}/${platform}.yml" "woodpecker-build-platform.sh ${platform}"
  assert_contains "${workflows}/${platform}.yml" "woodpecker-package-platform.mjs ${platform}"
done
assert_contains "${workflows}/release.yml" 'woodpecker-release.sh'
assert_contains "${packager}" 'woodpecker-release-evidence.mjs'
assert_contains "${packager}" 'scripts/extract-release-bundle.sh'
assert_contains "${packager}" 'windows/build-msi.sh'
assert_contains "${packager}" 'windows/build-exe.sh'
assert_contains "${packager}" 'macos/build-dmg.sh'
assert_contains "${packager}" 'macos/Formula/beskid.rb.tpl'
assert_contains "${packager}" 'deb/build-deb.sh'
assert_contains "${packager}" 'assets/icons/beskid-512.png'
assert_contains "${packager}" 'icon:auto-resize=256,128,96,64,48,32,16'
assert_contains "${packager}" 'icons/beskid.ico'
assert_contains "${publisher}" 'beskid-${version}-windows-amd64.exe'
assert_contains "${publisher}" 'beskid-${version}-macos-arm64.dmg'
assert_contains "${publisher}" 'beskid-${version}-amd64.deb'
assert_contains "${publisher}" 'publication requires CI manual main and GH_TOKEN'
assert_contains "${publisher}" 'publish-release-stream.sh'
assert_contains "${publisher}" 'gh release upload "cli-v${version}"'
if grep -Eiq 'linux-snap|snapcraft|canonical/action-(build|publish)|SNAPCRAFT_STORE_CREDENTIALS' "${workflows}"/*.yml "${packager}" "${publisher}"; then
  echo "retired Snap distribution must not remain in release automation" >&2
  exit 1
fi
if find "${root}" -type f \( -path '*/snap/*' -o -iname '*snap*' \) -print -quit | grep -q .; then
  echo "retired Snap recipes or documentation remain in beskid_distrib" >&2
  exit 1
fi
if grep -Riq -E 'snap store|snapcraft|snap install|linux-snap|SNAPCRAFT_STORE_CREDENTIALS' \
  "${root}/README.md" "${root}/SECRETS.md" "${root}/docs"; then
  echo "retired Snap claims or credentials remain in distribution documentation" >&2
  exit 1
fi

# Documentation and metadata describe the Woodpecker pipeline that exists, not the
# retired GitHub Actions one. SECRETS.md may name the retired secrets only to say
# they are unused, so it is checked for the real secret instead.
if grep -RIn -E 'cli-latest|lsp-latest|distribute\.yml|DISTRIB_GH_PAT|HOMEBREW_TAP_GIT_TOKEN|homebrew-releaser|macos-brew|windows-msi|macos-dmg' \
  "${root}/README.md" "${root}/docs" "${root}/docker" "${root}/macos" "${root}/assets"; then
  echo "retired GitHub Actions or pre-Woodpecker names remain in distribution documentation" >&2
  exit 1
fi
assert_contains "${root}/SECRETS.md" 'compiler_release_token'
assert_contains "${workflows}/release.yml" 'from_secret: compiler_release_token'

# `beskid build` and `beskid run` link with the system C driver, so every Linux
# consumer of the toolchain must be able to get one.
assert_contains "${root}/deb/debian/control" 'Recommends: gcc | c-compiler, libc6-dev'
assert_contains "${root}/docker/Dockerfile" 'gcc libc6-dev'
assert_contains "${root}/docker/Dockerfile.runner" 'gcc'
if grep -Fq 'BESKID_VERSION' "${root}/docker/docker-compose.yml" "${root}/docker/README.md"; then
  echo "container docs and compose must not pass a build argument the Dockerfiles never declare" >&2
  exit 1
fi

bash "${root}/tests/distribution-scripts.test.sh"
bash "${root}/tests/windows-wix-contract.test.sh"

printf 'Distribution static tests OK\n'
