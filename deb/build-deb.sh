#!/usr/bin/env bash
# Build the Beskid .deb package from the verified full target bundle.
#
# This does NOT rebuild from Cargo (cargo-deb is the wrong tool for that reason:
# the distrib pipeline consumes already-built release assets). Instead it
# assembles a dpkg-deb control tree from deb/debian/, copies the binaries into
# the FHS layout (/usr/bin), stamps the version + installed-size, and runs
# `dpkg-deb --build`.
#
# Usage: build-deb.sh <version> <build-dir>
#   version    resolved semver (e.g. 0.4.0)
#   build-dir  verified target bundle root (bin + ABI-v5 lib + corelib/packages)
#
# Output: beskid-<version>-amd64.deb in the caller's CWD.
set -euo pipefail

VERSION="${1:?version (semver)}"
BUILD_DIR="${2:?build-dir (verified target bundle root)}"

DISTRIB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CLI_BIN="${BUILD_DIR}/bin/beskid"
LSP_BIN="${BUILD_DIR}/bin/beskid_lsp"
UP_BIN="${BUILD_DIR}/bin/beskid-up"
[[ -f "$CLI_BIN" ]] || { echo "Missing $CLI_BIN" >&2; exit 1; }
[[ -f "$LSP_BIN" ]] || { echo "Missing $LSP_BIN" >&2; exit 1; }
[[ -f "$UP_BIN" ]] || { echo "Missing $UP_BIN" >&2; exit 1; }
[[ -d "${BUILD_DIR}/lib/beskid-runtime/abi-5" ]] || { echo "Missing ABI-v5 runtime kit" >&2; exit 1; }
[[ -f "${BUILD_DIR}/beskid_corelib/corelib.bproj" ]] || { echo "Missing bundled corelib" >&2; exit 1; }
[[ -d "${BUILD_DIR}/packages" ]] || { echo "Missing bundled packages" >&2; exit 1; }

# Assemble the package tree under a clean staging dir.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

PKGROOT="${STAGE}/beskid"
mkdir -p "${PKGROOT}/usr/bin" "${PKGROOT}/usr/share/doc/beskid" "${PKGROOT}/DEBIAN"

# Binaries into /usr/bin (already on PATH on Debian/Ubuntu by default).
cp -a "${BUILD_DIR}/bin/." "${PKGROOT}/usr/bin/"
cp -a "${BUILD_DIR}/lib" "${PKGROOT}/usr/lib"
cp -a "${BUILD_DIR}/beskid_corelib" "${PKGROOT}/usr/beskid_corelib"
cp -a "${BUILD_DIR}/packages" "${PKGROOT}/usr/packages"
cp -a "${BUILD_DIR}/release-version.txt" "${PKGROOT}/usr/release-version.txt"
chmod 0755 "${PKGROOT}/usr/bin/beskid" "${PKGROOT}/usr/bin/beskid_lsp" "${PKGROOT}/usr/bin/beskid-up"
install -m0644 "${DISTRIB_ROOT}/LICENSE" "${PKGROOT}/usr/share/doc/beskid/copyright"
install -m0644 "${DISTRIB_ROOT}/NOTICE" "${PKGROOT}/usr/share/doc/beskid/NOTICE"

# Control tree: stamp version + installed-size, copy maintainer scripts.
installed_kb="$(du -sk "${PKGROOT}/usr" | awk '{print $1}')"

sed -e "s/__VERSION__/${VERSION}/" \
    -e "s/__INSTALLED_SIZE_KB__/${installed_kb}/" \
    "${DISTRIB_ROOT}/deb/debian/control" > "${PKGROOT}/DEBIAN/control"
install -m0755 "${DISTRIB_ROOT}/deb/debian/postinst" "${PKGROOT}/DEBIAN/postinst"
install -m0755 "${DISTRIB_ROOT}/deb/debian/prerm"    "${PKGROOT}/DEBIAN/prerm"

# Build.
out="beskid-${VERSION}-amd64.deb"
dpkg-deb --build --root-owner-group "$PKGROOT" "$out"
echo "built ${out}"
