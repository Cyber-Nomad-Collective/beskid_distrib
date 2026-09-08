# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) when applicable.

## [Unreleased]

### Changed

- Build MSI, DMG, Debian, Homebrew, and OCI distributions from the immutable
  verified target bundle, preserving the complete no-environment-variable
  install prefix with CLI, LSP, updater, ABI-v5 runtime kit, corelib, and
  bundled packages.
- License distribution tooling under Apache-2.0, declare the license across
  Homebrew, Windows, Debian, DMG, and OCI metadata, and carry license notices
  in packaged artifacts.

### Removed

- Retire Snap distribution completely: remove its classic-confinement recipe,
  Store credentials, operator guides, workflow contract, and published-channel
  claims so it cannot block supported release lanes.

### Fixed

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
