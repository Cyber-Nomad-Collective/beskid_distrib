# macOS Guide — Homebrew and DMG distribution

The superrepo's Woodpecker release pipeline renders the formula from
`beskid_distrib/macos/Formula/beskid.rb.tpl` using the immutable version and
SHA-256 of the `aarch64-apple-darwin` bundle, then
`scripts/ci/publish-homebrew-formula.sh` commits it to the
`Cyber-Nomad-Collective/beskid_homebrew` tap (stable `X.Y.Z` releases only).
The macOS packaging step wraps the same verified bundle into `Beskid.app` with
`macos/build-dmg.sh` and uploads the DMG to the corresponding compiler release.

## Prerequisites (one-time, manual)

1. **Create the tap repo.** Create an **empty** repo named `beskid_homebrew`
   under `Cyber-Nomad-Collective` (no README/license; the publish script
   creates `Formula/beskid.rb`). Homebrew convention: the tap repo must be
   named `homebrew-<something>` to be installable as
   `brew tap <org>/<something>`. We register `beskid_homebrew` and users tap
   it as `cyber-nomad-collective/beskid` (Homebrew strips the `homebrew-`
   prefix from the repo name when matching the tap).

2. **Verify install path.** After the first publish, users run:
   ```sh
   brew tap cyber-nomad-collective/beskid
   brew install beskid
   beskid --version
   ```

## Secrets

Formula publication and the DMG upload use the release job's
`compiler_release_token`, which needs contents write access on
`beskid_homebrew` and release write access on `beskid_compiler`. See
`SECRETS.md`. No separate Homebrew token exists.

## Building programs needs the Xcode Command Line Tools

`beskid build` and `beskid run` link with `cc`, and static libraries also use
`libtool` and `ranlib`. Install the tools once with:

```sh
xcode-select --install
```

`beskid test` runs tests in the JIT and does not need them.

## Apple Silicon only

The compiler pipeline builds only `aarch64-apple-darwin`. The formula
declares `on_intel { depends_on arch: :arm }` so `brew install beskid` on an
Intel Mac fails with a clear arch-mismatch message rather than a binary crash.
Adding Intel later requires adding an `x86_64-apple-darwin` target to the
Woodpecker macOS build and the bundle extractor's supported targets, fetching
that bundle, and adding a second
`on_intel do ... end` block pointing at the Intel URL + sha256.

## Signing and notarization

The current DMG is unsigned. Gatekeeper can warn when a browser-downloaded DMG
is opened. Add Developer ID signing and notarization before declaring the DMG
as a trusted public release channel; Homebrew remains the recommended
package-managed installation path until then.
