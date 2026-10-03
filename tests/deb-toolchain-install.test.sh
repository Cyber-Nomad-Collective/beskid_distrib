#!/usr/bin/env bash
# Install test: run only as root in a fresh Ubuntu 24.04 Docker/Podman container.
# Usage: bash tests/deb-toolchain-install.test.sh /input/beskid-<version>-amd64.deb
set -euo pipefail

package="${1:?path to the candidate DEB}"
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ ( -f /.dockerenv || -f /run/.containerenv ) && "$EUID" == 0 ]] || {
  echo 'Run this install test only in a disposable root Docker/Podman container' >&2
  exit 2
}
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 && "$(uname -m)" == x86_64 ]] || {
  echo 'This qualification requires Ubuntu 24.04 x86_64' >&2
  exit 2
}
[[ -f "$package" ]] || { echo 'Candidate DEB is missing' >&2; exit 2; }
[[ "$(dpkg-deb -f "$package" Package)" == beskid &&
   "$(dpkg-deb -f "$package" Architecture)" == amd64 ]] || {
  echo 'Candidate must be the beskid amd64 package' >&2
  exit 2
}
for tool in beskid clang cc ar ranlib; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "Qualification requires a clean container without preinstalled $tool" >&2
    exit 2
  fi
done

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$package"
for tool in clang cc ar ranlib; do
  command -v "$tool" || { echo "DEB did not install required tool: $tool" >&2; exit 1; }
done
[[ "$(command -v beskid)" == /usr/bin/beskid ]]
/usr/bin/beskid --version

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
cp "$root/tests/fixtures/deb-console/probe.c" "$work/probe.c"
clang -target x86_64-unknown-linux-gnu -std=c11 -fPIC -c "$work/probe.c" -o "$work/probe.o"
ar rcs "$work/probe.a" "$work/probe.o"
ranlib "$work/probe.a"
cc "$work/probe.a" -o "$work/probe"
"$work/probe"

mkdir -p "$work/home" "$work/project"
cp -a "$root/tests/fixtures/deb-console/." "$work/project/"
export HOME="$work/home"
unset BESKID_CORELIB_ROOT CORELIB_ROOT BESKID_RUNTIME_PREFIX BESKID_CLI_BIN
unset GH_TOKEN GITHUB_TOKEN NODE_AUTH_TOKEN NPM_TOKEN
cd "$work/project"
/usr/bin/beskid analyze --project Smoke.bproj --plain
sha256sum Project.lock > "$work/lock.sha256"
/usr/bin/beskid build --project Smoke.bproj --locked --plain
/usr/bin/beskid run --project Smoke.bproj --locked --plain
sha256sum --check "$work/lock.sha256"
echo 'Clean DEB toolchain install and AOT build/run: PASS'
