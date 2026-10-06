#!/usr/bin/env bash
# Create one channel-owned OCI input from a qualified immutable full target bundle.
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
version="${1:?immutable release version}"
destination="${2:?new OCI bundle destination}"
[[ ! -e "${destination}" && ! -L "${destination}" ]] || {
  echo "Container toolchain destination already exists: ${destination}" >&2; exit 1;
}
parent="$(dirname "${destination}")"
mkdir -p "${parent}"
parent="$(cd "${parent}" && pwd)"
destination="${parent}/$(basename "${destination}")"
name="$(basename "${destination}")"
lock="${parent}/.${name}.container-prepare-lock"
mkdir "${lock}" || { echo 'Another container preparation owns this destination.' >&2; exit 1; }
stage=""
cleanup() { [[ -z "${stage}" ]] || rm -rf "${stage}"; rmdir "${lock}"; }
trap cleanup EXIT
stage="$(mktemp -d "${parent}/.beskid-container.XXXXXX")"
bundle="${stage}/${name}"
bash "${root}/fetch-release-bundle.sh" "${version}" x86_64-unknown-linux-gnu "${bundle}"
node "${root}/stamp-installation-owner.mjs" "${bundle}" container "${version}" x86_64-unknown-linux-gnu
[[ ! -e "${destination}" && ! -L "${destination}" ]] || { echo 'Container destination appeared during preparation.' >&2; exit 1; }
# Source basename equals the final basename: no-clobber targets exactly that
# entry in its parent, rather than moving into an existing destination directory.
mv -n "${bundle}" "${parent}/"
[[ ! -e "${bundle}" ]] || { echo 'Container destination appeared during atomic publication.' >&2; exit 1; }
echo "Prepared verified container toolchain at ${destination}"
