#!/usr/bin/env bash
# Installed-kit smoke for the Homebrew formula. Run ONLY on a disposable macOS arm64 host
# that has no `beskid` keg and no tap named local/beskid-kit-test. It installs and uninstalls
# a real keg. Never run it on a developer machine.
# Usage: bash tests/homebrew-kit-install.test.sh <candidate.tar.gz> [<0.5.2.tar.gz>]
set -euo pipefail

candidate="${1:?path to the candidate aarch64-apple-darwin tarball}"
legacy="${2:-}"
root="$(cd "$(dirname "$0")/.." && pwd)"
tap_user=local
tap_repo=beskid-kit-test
tap="${tap_user}/${tap_repo}"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || {
  echo 'This qualification requires macOS arm64' >&2; exit 2; }
command -v brew >/dev/null || { echo 'Homebrew is required' >&2; exit 2; }
if brew list --formula --versions beskid 2>/dev/null | grep -q .; then
  echo 'Refusing to run: a beskid keg exists. Use a disposable host.' >&2; exit 2
fi
if brew tap | grep -qx "$tap"; then
  echo "Refusing to run: tap $tap already exists" >&2; exit 2
fi
[[ -f "$candidate" ]] || { echo 'Candidate tarball is missing' >&2; exit 2; }
[[ -z "$legacy" || -f "$legacy" ]] || { echo '0.5.2 tarball path is missing' >&2; exit 2; }

work="$(mktemp -d)"
cleanup() {
  brew uninstall --formula --force beskid >/dev/null 2>&1 || true
  brew untap "$tap" >/dev/null 2>&1 || true
  rm -rf -- "$work"
}
trap cleanup EXIT

render_formula() { # tarball -> installs rendered formula into the temp tap
  local tarball="$1" version sha formula
  mkdir -p "$work/peek"
  tar -xzf "$tarball" -C "$work/peek" --include='*release-version.txt' 2>/dev/null || tar -xzf "$tarball" -C "$work/peek"
  version="$(find "$work/peek" -name release-version.txt -print -quit | xargs cat | tr -d '\n')"
  rm -rf "$work/peek"
  [[ -n "$version" ]] || { echo 'Tarball has no release-version.txt' >&2; exit 1; }
  sha="$(shasum -a 256 "$tarball" | awk '{print $1}')"
  formula="$(brew --repository)/Library/Taps/${tap_user}/homebrew-${tap_repo}/Formula/beskid.rb"
  mkdir -p "$(dirname "$formula")"
  sed -e "s|__VERSION__|${version}|g" -e "s|__SHA256__|${sha}|g" \
      -e "s|^  url \".*\"|  url \"file://$(cd "$(dirname "$tarball")" && pwd)/$(basename "$tarball")\"|" \
      "$root/macos/Formula/beskid.rb.tpl" > "$formula"
  grep -q 'preserve_rpath' "$formula"
  RENDERED_VERSION="$version"
}

brew tap-new --no-git "$tap" >/dev/null

# 1. The 0.5.2 tarball (absolute staging dylib ID) must fail the install precondition.
if [[ -n "$legacy" ]]; then
  render_formula "$legacy"
  if brew install --formula "$tap/beskid" >"$work/legacy.out" 2>&1; then
    echo '0.5.2 tarball unexpectedly installed' >&2; exit 1
  fi
  grep -Eq 'install ID|LC_RPATH|non-system dependency' "$work/legacy.out" || {
    cat "$work/legacy.out" >&2; echo '0.5.2 failed for an unexpected reason' >&2; exit 1; }
  ! brew list --formula --versions beskid 2>/dev/null | grep -q . || { echo '0.5.2 left a keg' >&2; exit 1; }
fi

# 2. The candidate installs, tests, and keeps the kit dylib bytes exact.
render_formula "$candidate"
extract="$work/extract"
mkdir -p "$extract"
tar -xzf "$candidate" -C "$extract"
brew install --formula "$tap/beskid"
brew test "$tap/beskid"

keg_libexec="$(brew --prefix beskid)/libexec"
for profile in debug release; do
  relative="lib/beskid-runtime/abi-5/aarch64-apple-darwin/${profile}/shared/libbeskid_runtime.dylib"
  original="$(find "$extract" -path "*/${relative}" -print -quit)"
  [[ -f "$original" ]] || { echo "Tarball lacks ${relative}" >&2; exit 1; }
  installed="${keg_libexec}/${relative}"
  want="$(shasum -a 256 "$original" | awk '{print $1}')"
  have="$(shasum -a 256 "$installed" | awk '{print $1}')"
  [[ "$want" == "$have" ]] || { echo "${profile} kit dylib changed: tarball $want, keg $have" >&2; exit 1; }
  meta="$(dirname "$(dirname "$installed")")/abi.json"
  recorded="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["artifacts"]["shared_library"]["sha256"])' "$meta")"
  [[ "$recorded" == "$have" ]] || { echo "${profile} kit metadata sha256 $recorded differs from keg $have" >&2; exit 1; }
  [[ "$(otool -D "$installed" | tail -n 1)" == "@rpath/libbeskid_runtime.dylib" ]] || {
    echo "${profile} kit dylib install ID changed" >&2; exit 1; }
  codesign -dv "$installed" 2>&1 | grep -q 'linker-signed' || {
    echo "${profile} kit dylib lost its linker signature" >&2; exit 1; }
done

brew uninstall --formula beskid
brew untap "$tap"
echo 'Homebrew kit install, byte equality and linker signature: PASS'
