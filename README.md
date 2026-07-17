# beskid_distrib

Platform-specific packaging recipes, assets, and guides for the Beskid
compiler CLI/LSP. This repository is a **content-only submodule** of the
[`beskid`](https://github.com/Cyber-Nomad-Collective/beskid) superrepo — the
CI orchestration lives in the superrepo at
`.github/workflows/distribute.yml`, not here.

## What lives here

- `assets/icons/` — derived branding (`.ico`, `.png`, `.svg`) used by installers.
- `windows/` — WiX v4 MSI source plus a Burn bootstrapper that produces the
  Windows MSI and end-user `.exe` installer.
- `macos/build-dmg.sh` — builds the portable `Beskid.app` DMG from the CLI and
  LSP binaries; Homebrew remains available for package-managed installs.
- `macos/Formula/beskid.rb.tpl` — Homebrew formula template rendered with the
  rolling version + sha256 and pushed to `beskid_homebrew` by
  `homebrew-releaser`.
- `deb/` — `dpkg-deb` control tree template + `build-deb.sh` for Ubuntu/Debian.
- `snap/snapcraft.yaml` — Snapcraft definition (classic confinement).
- `scripts/` — helpers to resolve the current version and fetch immutable
  `cli-v<version>` / `lsp-v<version>` release assets from `beskid_compiler`.
- `docs/` — per-platform guides for obtaining CI secrets, plus `SECRETS.md`.

## Where packages publish

| Platform | Target |
|---|---|
| Windows `.msi` + `.exe` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| macOS `.dmg` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| macOS Homebrew | `Cyber-Nomad-Collective/beskid_homebrew` tap (`brew install beskid`) |
| Ubuntu/Debian `.deb` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| Snap | Snap Store (`snap install beskid --classic`) |

## Trigger

The distrib pipeline runs in the superrepo on `workflow_run` of the `Compiler`
workflow. It uses the rolling aliases only to discover the version, fetches
the matching immutable assets, wraps them into per-platform packages, and
publishes both immutable assets and rolling aliases.

See `docs/SECRETS.md` for the credentials required to run a full pipeline.
