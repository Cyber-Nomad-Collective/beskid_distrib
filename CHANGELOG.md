# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) when applicable.

## [Unreleased]

### Added

- Recommend a C compiler and libc headers from the Debian package
  (`Recommends: gcc | c-compiler, libc6-dev`) and install `gcc` and `libc6-dev`
  in both container images, because `beskid build` and `beskid run` link with
  the system `cc`, `ar`, and `ranlib`. Document the same requirement for
  Ubuntu and for macOS (Xcode Command Line Tools).
- Cover the 0.5 release line in the version-contract tests and guard the
  documentation and toolchain contracts against regression.
- Chain the Microsoft Visual C++ 2015-2022 Redistributable (x64) in the
  Windows setup `.exe`. The bundle embeds the Authenticode-verified
  `vc_redist.x64.exe`, installs it only when the 14.40+ x64 runtime is missing,
  and keeps it on uninstall. The standalone MSI stops with an actionable
  message when the runtime is missing.
- Document Windows end-user prerequisites: the redistributable for every
  command, and the non-redistributable MSVC Build Tools and Windows SDK for
  `beskid build` and `beskid run`.
- Present macOS releases in a branded Finder DMG with a Beskid.app-to-
  Applications drag-to-install shortcut.

### Changed

- Describe the Woodpecker release pipeline instead of the retired GitHub Actions
  one across the README, per-platform guides, `SECRETS.md`, and the Homebrew
  formula template: `cli-v<version>` plus rolling `cli-stable` / `cli-unstable`
  releases, and the single `compiler_release_token` secret the release job uses.
- State plainly that the container images are not built or published by any
  pipeline, and document how to build them locally from a verified bundle.
- Describe the whole installed toolchain, not just the CLI and LSP, in the
  Debian package description.
- Check native package and immutable release contracts against Woodpecker build,
  packaging, and publication authority after retirement of the GitHub workflow.

- Use canonical Emerald Ridge artwork for installer SVG and PNG assets.

- Build MSI, DMG, Debian, Homebrew, and OCI distributions from the immutable
  verified target bundle, preserving the complete no-environment-variable
  install prefix with CLI, LSP, updater, ABI-v5 runtime kit, corelib, and
  bundled packages.
- License distribution tooling under Apache-2.0, declare the license across
  Homebrew, Windows, Debian, DMG, and OCI metadata, and carry license notices
  in packaged artifacts.

### Removed

- Drop the `BESKID_VERSION` build argument from the compose file and container
  documentation; neither Dockerfile declares it.
- Retire Snap distribution completely: remove its classic-confinement recipe,
  Store credentials, operator guides, workflow contract, and published-channel
  claims so it cannot block supported release lanes.

### Fixed

- Write the branded macOS DMG layout directly through `dmgbuild`, avoiding
  Finder AppleEvents that time out in non-interactive build sessions.
- Build the Windows MSI explicitly as x64, use WiX v4-compatible UTF-8 and
  summary metadata, and remove the invalid downgrade-message format token and
  duplicate per-machine property so standard MSI validation passes.
- Reject links and special files before extracting an authenticated compiler
  bundle so archive topology cannot escape the atomic staging directory.
- Correct OCI build contexts and copy the verified toolchain prefix into both
  the base and runner images instead of downloading an unverified bare CLI
  during the image build.
- Verify fetched compiler assets against the immutable release-state manifest and GitHub's
  publisher-computed SHA-256 before exposing them to installer packaging, failing closed when
  authority, membership, or checksum data is missing or mismatched.
- Accept canonical `X.Y.Z-unstable` compiler releases throughout immutable
  asset resolution, project them to numeric Windows installer metadata without
  changing public artifact names, and pin/load matching WiX UI and Burn
  extensions for reproducible MSI and bootstrapper builds.
