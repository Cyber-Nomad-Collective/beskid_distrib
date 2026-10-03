# beskid_distrib

Platform-specific packaging recipes, assets, and guides for the Beskid
compiler toolchain. This repository is a **content-only submodule** of the
[`beskid`](https://github.com/Cyber-Nomad-Collective/beskid) superrepo — the
build and packaging orchestration lives in the superrepo's Woodpecker
pipelines (`.woodpecker/` and `scripts/ci/`), not here. Publication is a
separately reviewed manual operation.

## What lives here

- `assets/icons/` — Beskid source branding used by installers.
- `windows/` — WiX v4 MSI source plus a Burn bootstrapper that produces the
  Windows MSI and end-user `.exe` installer. The setup EXE downloads a pinned
  Visual C++ runtime and offers an unchecked MSVC/SDK/LLVM developer-tools
  choice; see the [Windows installation guide](docs/Windows_Guide.md).
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
- `docs/` — per-platform installation, packaging, and operations guides.

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

Woodpecker packages qualified, immutable compiler bundles on the matching
native host. Packaging records checksums and does not publish. Stable
publication is a separate reviewed manual operation. The pipeline builds
verified per-target bundles from the exact source commit, then wraps those
immutable `v<version>` bundles into platform packages. The superrepo pins
this repository by gitlink, so changes here reach a release only after that
pointer is bumped.

Every supported package preserves one install prefix: `bin/`,
`lib/beskid-runtime/abi-5/` (debug and release), the managed
`beskid_corelib/` workspace (including its `packages/` and integrity marker),
and `release-version.txt`. The CLI derives the runtime kit and corelib from its
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

`beskid build` and `beskid run` compile native platform objects with Clang and
link with the system C compiler driver (`cc`). Linux static libraries use `ar`
and `ranlib`; macOS uses `libtool`. Windows needs LLVM and the MSVC tools.
The `.deb` requires Clang, a C compiler, binutils, and C library headers so
build/run also work with recommendations disabled. See the per-platform guides
for prerequisites and the Ubuntu guide for the clean-container install test.

See `SECRETS.md` for historical and manual-publishing credential guidance.

## License

Beskid-owned distribution tooling is licensed under the
[Apache License 2.0](LICENSE). Packaged compiler binaries carry their own
Apache-2.0 license and notice material.
