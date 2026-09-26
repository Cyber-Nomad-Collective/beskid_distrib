# beskid_distrib

Platform-specific packaging recipes, assets, and guides for the Beskid
compiler toolchain. This repository is a **content-only submodule** of the
[`beskid`](https://github.com/Cyber-Nomad-Collective/beskid) superrepo — the
CI orchestration lives in the superrepo's Woodpecker pipelines, not here.

## What lives here

- `assets/icons/` — Beskid source branding used by installers.
- `windows/` — WiX v4 MSI source plus a Burn bootstrapper that produces the
  Windows MSI and end-user `.exe` installer. The setup EXE downloads a pinned
  Visual C++ runtime and offers an unchecked MSVC/SDK/LLVM developer-tools
  choice; see the [Windows installation guide](docs/Windows_Guide.md).
- `macos/build-dmg.sh` — builds the portable `Beskid.app` DMG from the CLI and
  LSP binaries; Homebrew remains available for package-managed installs.
- `macos/Formula/beskid.rb.tpl` — Homebrew formula template rendered with the
  rolling version + sha256 and pushed to `beskid_homebrew` by
  `homebrew-releaser`.
- `deb/` — `dpkg-deb` control tree template + `build-deb.sh` for Ubuntu/Debian.
- `docker/` — Container images (generic + GitHub Actions runner).
- `scripts/` — helpers to resolve the current version and fetch immutable
  verified `v<version>` target bundles from `beskid_compiler`.
- `docs/` — platform installation and operations guides, plus `SECRETS.md`.

## Where packages publish

| Platform | Target |
|---|---|
| Windows `.msi` + `.exe` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| macOS `.dmg` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| macOS Homebrew | `Cyber-Nomad-Collective/beskid_homebrew` tap (`brew install beskid`) |
| Ubuntu/Debian `.deb` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| Container images | `ghcr.io/cyber-nomad-collective/beskid` + `beskid-runner` |

## Trigger

Woodpecker packages qualified, immutable compiler bundles on the matching
native host. Packaging records checksums and does not publish. Stable
publication is a separate reviewed manual operation.

Every supported package preserves one install prefix: `bin/`,
`lib/beskid-runtime/abi-5/`, `beskid_corelib/`, `packages/`, and
`release-version.txt`. The CLI derives the runtime kit and corelib from its
own executable under `<prefix>/bin`, so installed packages and OCI images do
not require `BESKID_RUNTIME_PREFIX` or `BESKID_CORELIB_ROOT`.

See `docs/SECRETS.md` for historical and publishing credential guidance.

## License

Beskid-owned distribution tooling is licensed under the
[Apache License 2.0](LICENSE). Packaged compiler binaries carry their own
Apache-2.0 license and notice material.
