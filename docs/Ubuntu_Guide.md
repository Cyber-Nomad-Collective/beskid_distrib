# Ubuntu / Debian Guide — CI secrets for the .deb pipeline

The Ubuntu packaging job (`ubuntu-deb`) runs
`beskid_distrib/deb/build-deb.sh`, which wraps the prebuilt linux-amd64 CLI +
LSP binaries into a `.deb` via `dpkg-deb --build`, then uploads the `.deb` to
the `cli-latest` / `cli-v<version>` release on `beskid_compiler`.

## Secret required

| Secret | Purpose |
|---|---|
| `DISTRIB_GH_PAT` | Download the rolling `beskid-linux-amd64` + `beskid_lsp-linux-amd64` from `beskid_compiler`, and upload the built `.deb` back to that release. (Shared with Windows.) |

No Launchpad account, no GPG signing key, no apt repo is required for v1 — the
`.deb` is distributed as a release asset that users download and install with
`dpkg -i` or `apt install ./beskid-<version>-amd64.deb`. This is the simplest
distribution path and the one most users expect for a single-binary CLI.

## Obtaining `DISTRIB_GH_PAT`

See `Windows_Guide.md` — the same `DISTRIB_GH_PAT` secret covers Windows and
Ubuntu. Set it once.

## What the .deb does

The package layout (from `beskid_distrib/deb/debian/control` + `build-deb.sh`):

- `beskid` and `beskid_lsp` are installed to `/usr/bin/` (on PATH by default on
  Debian/Ubuntu — no profile edits needed).
- `postinst` enforces `0755` mode on both binaries and prints a confirmation.
- `prerm` is a no-op (the binaries leave no user data).
- `control` declares `Depends: libc6` and `Architecture: amd64`.
- The package version is stamped from the rolling release semver.

## Install (end users)

```sh
# download beskid-<version>-amd64.deb from the cli-latest release on beskid_compiler
sudo apt install ./beskid-<version>-amd64.deb
# verify:
beskid --version
```

`apt install ./<file>.deb` resolves dependencies (libc6) automatically;
`dpkg -i` works too but does not pull dependencies.

## Future: apt repo (not in v1)

If you later want `apt update && apt install beskid` (without a manual
download), host the `.deb` in an apt repo — either on GitHub Pages with
`aptly` + a GPG-signed `Release` file (secrets: `APT_GPG_PRIVATE_KEY`,
`APT_GPG_PASSPHRASE`), or on a hosted apt repo (Cloudsmith, Gemfury,
Launchpad PPA). The `.deb` produced today is identical and reusable; only the
publish target and signing change.
