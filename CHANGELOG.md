# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) when applicable.

## [Unreleased]

### Added

- Document the Windows setup's runtime-only default, optional native tools,
  unattended selection, vendor downloads, standalone MSI, and recovery steps.
- Document the disposable-VM installer matrix and its release-evidence gate.
- Chain the pinned Microsoft Visual C++ 2015-2022 Redistributable (x64) as
  a verified remote payload in the Windows setup `.exe`, installing it only
  when the 14.40+ x64 runtime is missing and retaining it on uninstall. The
  standalone MSI stops with an actionable message when the runtime is missing.
- Install `gcc` and `libc6-dev` in both container images because native
  linking uses the system C toolchain. Document the macOS requirement for
  Xcode Command Line Tools.
- Add a clean Ubuntu DEB installation regression that disables recommendations,
  exercises Clang/cc/binutils, and builds/runs an installed-prefix Beskid project
  while preserving its lockfile.
- Cover the 0.5 release line in the version-contract tests and guard the
  documentation and toolchain contracts against regression.
- Document Windows end-user prerequisites: the redistributable for every
  command, and the non-redistributable MSVC Build Tools and Windows SDK for
  `beskid build` and `beskid run`.
- Present macOS releases in a branded Finder DMG with a Beskid.app-to-
  Applications drag-to-install shortcut.

### Changed

- Install Clang and binutils explicitly in both toolchain container stages;
  qualify each actual image with offline native compilation and installed-prefix
  Beskid build/run rather than relying on package-list assertions alone.
- Require Clang, a C compiler, binutils, and libc headers as DEB dependencies;
  native bootstrap compilation cannot use GCC in place of Clang.
- Describe the Woodpecker release pipeline instead of the retired GitHub Actions
  one across the README, per-platform guides, `SECRETS.md`, and the Homebrew
  formula template: `cli-v<version>` plus rolling `cli-stable` / `cli-unstable`
  releases, and the single `compiler_release_token` secret the release job uses.
- State plainly that the superrepo's Woodpecker pipelines do not build these
  container images (the GitHub Actions lane was removed), and document how to
  build them locally from a verified bundle.
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

- Make the Windows setup directory choice effective: pass the branded Options
  path to MSI `INSTALLDIR`, default it to Program Files, and block an empty
  path even after returning through Options.
- Detect preexisting standard-path MSVC Build Tools and complete missing x64
  compiler/SDK components with the vendor bootstrapper's supported modify
  operation instead of skipping a partial installation; detect existing LLVM
  before offering opt-in installation. Check the actual x64 VC++ runtime DLL version in the standalone
  MSI because MSI raw DWORD registry searches return prefixed values such as
  `#44` rather than bare numbers.
- Require both runtime-kit profiles and the complete marker-bearing Corelib
  workspace inside release bundles and all native installers, matching the
  installed compiler's default build/run profile, Corelib discovery, and
  integrity checks.
- Download LLVM from its official versioned release URL instead of an expired
  GitHub CDN redirect, while retaining the locked hash and attestation checks.
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
