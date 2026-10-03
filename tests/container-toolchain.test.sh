#!/usr/bin/env bash
# Run in an already-built base or runner image, never install missing tools here.
# Usage: bash /test/tests/container-toolchain.test.sh <expected-version>
set -euo pipefail

version="${1:?expected Beskid version}"
root="$(cd "$(dirname "$0")/.." && pwd)"
[[ ( -f /.dockerenv || -f /run/.containerenv ) && "$(uname -m)" == x86_64 ]] || {
  echo 'Run this qualification only in a disposable Linux amd64 container' >&2
  exit 2
}
for tool in clang cc ar ranlib; do
  command -v "$tool" || { echo "Toolchain image is missing required tool: $tool" >&2; exit 1; }
done
cli=/opt/beskid/bin/beskid
[[ "$(command -v beskid)" == "$cli" ]]
[[ "$("$cli" --version)" == "beskid $version" ]]
[[ "$(cat /opt/beskid/release-version.txt)" == "$version" ]]

work="$(mktemp -d /tmp/beskid-container-qualification.XXXXXX)"
trap 'echo "Qualification evidence retained: $work"' EXIT
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
"$cli" analyze --project Smoke.bproj --plain
sha256sum Project.lock | tee "$work/lock.sha256"
"$cli" build --project Smoke.bproj --locked --plain
"$cli" run --project Smoke.bproj --locked --plain
sha256sum --check "$work/lock.sha256"
echo 'Container native toolchain and installed-prefix AOT build/run: PASS'
