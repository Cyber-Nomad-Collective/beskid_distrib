#!/usr/bin/env bash
# Build the Beskid .deb package by wrapping the prebuilt CLI + LSP binaries.
#
# This does NOT rebuild from Cargo (cargo-deb is the wrong tool for that reason:
# the distrib pipeline consumes already-built release assets). Instead it
# assembles a dpkg-deb control tree from deb/debian/, copies the binaries into
# the FHS layout (/usr/bin), stamps the version + installed-size, and runs
# `dpkg-deb --build`.
#
# Usage: build-deb.sh <version> <build-dir>
#   version    resolved semver (e.g. 0.4.0)
#   build-dir  directory containing beskid (linux-amd64) + beskid_lsp (linux-amd64)
#
# Output: beskid-<version>-amd64.deb in the caller's CWD.
set -euo pipefail

VERSION="${1:?version (semver)}"
BUILD_DIR="${2:?build-dir (contains the fetched linux-amd64 binaries)}"

DISTRIB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CLI_BIN="${BUILD_DIR}/beskid-linux-amd64"
LSP_BIN="${BUILD_DIR}/beskid_lsp-linux-amd64"
[[ -f "$CLI_BIN" ]] || { echo "Missing $CLI_BIN" >&2; exit 1; }
[[ -f "$LSP_BIN" ]] || { echo "Missing $LSP_BIN" >&2; exit 1; }

# Assemble the package tree under a clean staging dir.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

PKGROOT="${STAGE}/beskid"
mkdir -p "${PKGROOT}/usr/bin" "${PKGROOT}/DEBIAN"

# Binaries into /usr/bin (already on PATH on Debian/Ubuntu by default).
cp -f "$CLI_BIN" "${PKGROOT}/usr/bin/beskid"
cp -f "$LSP_BIN" "${PKGROOT}/usr/bin/beskid_lsp"
chmod 0755 "${PKGROOT}/usr/bin/beskid" "${PKGROOT}/usr/bin/beskid_lsp"

# Control tree: stamp version + installed-size, copy maintainer scripts.
installed_kb=$(( ($(stat -c%s "${PKGROOT}/usr/bin/beskid" 2>/dev/null || stat -f%z "${PKGROOT}/usr/bin/beskid") \
                + $(stat -c%s "${PKGROOT}/usr/bin/beskid_lsp" 2>/dev/null || stat -f%z "${PKGROOT}/usr/bin/beskid_lsp") \
                + 1023) / 1024 ))

sed -e "s/__VERSION__/${VERSION}/" \
    -e "s/__INSTALLED_SIZE_KB__/${installed_kb}/" \
    "${DISTRIB_ROOT}/deb/debian/control" > "${PKGROOT}/DEBIAN/control"
install -m0755 "${DISTRIB_ROOT}/deb/debian/postinst" "${PKGROOT}/DEBIAN/postinst"
install -m0755 "${DISTRIB_ROOT}/deb/debian/prerm"    "${PKGROOT}/DEBIAN/prerm"

# Build.
out="beskid-${VERSION}-amd64.deb"
dpkg-deb --build --root-owner-group "$PKGROOT" "$out"
echo "built ${out}"
