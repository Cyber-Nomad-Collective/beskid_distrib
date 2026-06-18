# beskid_distrib

Platform-specific packaging recipes, assets, and guides for the Beskid
compiler CLI/LSP. This repository is a **content-only submodule** of the
[`beskid`](https://github.com/Cyber-Nomad-Collective/beskid) superrepo — the
CI orchestration lives in the superrepo at
`.github/workflows/distribute.yml`, not here.

## What lives here

- `assets/icons/` — derived branding (`.ico`, `.png`, `.svg`) used by installers.
- `windows/` — WiX v4 source (`beskid.wxs`) + `build-msi.sh` that produces the
  Windows MSI (install-dir selection, PATH entry, uninstall entry).
- `macos/Formula/beskid.rb.tpl` — Homebrew formula template rendered with the
  rolling version + sha256 and pushed to `beskid_homebrew` by
  `homebrew-releaser`.
- `arch/PKGBUILD` — AUR `beskid-bin` package definition.
- `deb/` — `dpkg-deb` control tree template + `build-deb.sh` for Ubuntu/Debian.
- `snap/snapcraft.yaml` — Snapcraft definition (classic confinement).
- `scripts/` — helpers to fetch the rolling release assets and resolve the
  version from `beskid_compiler`.
- `docs/` — per-platform guides for obtaining CI secrets, plus `SECRETS.md`.

## Where packages publish

| Platform | Target |
|---|---|
| Windows `.msi` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| macOS | `Cyber-Nomad-Collective/beskid_homebrew` tap (`brew install beskid`) |
| Arch | AUR package `beskid-bin` (`yay -S beskid-bin`) |
| Ubuntu/Debian `.deb` | GitHub release on `beskid_compiler` (`cli-latest`, `cli-v<ver>`) |
| Snap | Snap Store (`snap install beskid --classic`) |

## Trigger

The distrib pipeline runs in the superrepo on `workflow_run` of the `Compiler`
workflow. It fetches the rolling `cli-latest` / `lsp-latest` assets from
`beskid_compiler`, wraps them into the per-platform packages, and publishes.

See `docs/SECRETS.md` for the credentials required to run a full pipeline.
