# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) when applicable.

## [Unreleased]

### Removed

- Retire Snap distribution completely: remove its classic-confinement recipe,
  Store credentials, operator guides, workflow contract, and published-channel
  claims so it cannot block supported release lanes.

### Fixed

- Accept canonical `X.Y.Z-unstable` compiler releases throughout immutable
  asset resolution, project them to numeric Windows installer metadata without
  changing public artifact names, and pin/load matching WiX UI and Burn
  extensions for reproducible MSI and bootstrapper builds.
