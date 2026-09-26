# beskid_distrib

Platform-specific packaging recipes, assets, and guides for the Beskid
compiler toolchain. This repository is a **content-only submodule** of the
[`beskid`](https://github.com/Cyber-Nomad-Collective/beskid) superrepo. The
build, packaging, and publication orchestration lives in the superrepo's
Woodpecker pipelines (`.woodpecker/` and `scripts/ci/`), not here.

## What lives here

- `assets/icons/` — derived branding (`.ico`, `.png`, `.svg`) used by installers.
- `windows/` — WiX v4 MSI source plus a Burn bootstrapper that produces the
  Windows MSI and end-user `.exe` installer.
- `macos/build-dmg.sh` — builds the portable `Beskid.app` DMG from the CLI and
  LSP binaries; Homebrew remains available for package-managed installs.
- `macos/Formula/beskid.rb.tpl` — Homebrew formula template rendered with the
  release version + sha256 and pushed to `beskid_homebrew` by the superrepo's
  `scripts/ci/publish-homebrew-formula.sh`.
- `deb/` — `dpkg-deb` control tree template + `build-deb.sh` for Ubuntu/Debian.
- `docker/` — Container image sources (generic + CI runner). No pipeline builds
  or publishes them today; see [Container images](#container-images).
- `scripts/` — helpers to resolve the current version and fetch immutable
  verified `v<version>` target bundles from `beskid_compiler`.
- `docs/` — per-platform install and packaging guides, plus `SECRETS.md`.

## Where packages publish

| Platform | Target |
|---|---|
| Windows `.msi` + `.exe` | GitHub release on `beskid_compiler` (`cli-v<ver>`, rolling `cli-stable` / `cli-unstable`) |
| macOS `.dmg` | GitHub release on `beskid_compiler` (`cli-v<ver>`, rolling `cli-stable` / `cli-unstable`) |
| macOS Homebrew | `Cyber-Nomad-Collective/beskid_homebrew` tap (`brew install beskid`) |
| Ubuntu/Debian `.deb` | GitHub release on `beskid_compiler` (`cli-v<ver>`, rolling `cli-stable` / `cli-unstable`) |

Release assets are named `beskid-<version>-amd64.deb`,
`beskid-<version>-macos-arm64.dmg`, and
`beskid-<version>-windows-amd64.{msi,exe}`.

## Trigger

Woodpecker builds a verified per-target bundle from the exact source commit,
then the release pipeline wraps that immutable `v<version>` bundle into the
per-platform packages here and publishes the immutable `cli-v<version>` assets
and the rolling `cli-stable` / `cli-unstable` aliases. The superrepo pins this
repository by gitlink, so a change here reaches a release only after the
superrepo's `beskid_distrib` pointer is bumped.

Every supported package preserves one install prefix: `bin/`,
`lib/beskid-runtime/abi-5/`, `beskid_corelib/`, `packages/`, and
`release-version.txt`. The CLI derives the runtime kit and corelib from its
own executable under `<prefix>/bin`, so installed packages and OCI images do
not require `BESKID_RUNTIME_PREFIX` or `BESKID_CORELIB_ROOT`.

## Container images

Woodpecker builds and pushes the five platform images (`site`, `learn`,
`tracker`, `nexus`, `pckg`) to `cr.beskid-lang.org/beskid/` with
`scripts/ci/woodpecker-platform-images.sh`; `learn` carries the Beskid CLI
toolchain. `docker/` here is different: a base toolchain image and a CI runner
image built from a verified bundle. Their old GitHub Actions lane was removed
with that workflow (superrepo commit `fcde7045`), and no pipeline in this
repository's superrepo builds them now. Build them locally as described in
`docker/README.md` until a Woodpecker lane is added.

## Building programs needs a C toolchain

`beskid build` and `beskid run` link with the system C compiler driver (`cc`)
plus `ar` and `ranlib` on Linux, and with `cc` and `libtool` on macOS. On
Windows they need the MSVC tools. The `.deb` recommends a compiler and C
library headers, the Docker images install them, and the per-platform guides
list the prerequisites. `beskid test` does not link programs.

See `SECRETS.md` for the credentials the release pipeline uses.

## License

Beskid-owned distribution tooling is licensed under the
[Apache License 2.0](LICENSE). Packaged compiler binaries carry their own
Apache-2.0 license and notice material.
