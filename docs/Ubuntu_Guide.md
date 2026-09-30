# Ubuntu / Debian Guide

The Linux packaging step runs `beskid_distrib/deb/build-deb.sh`, which wraps the
verified `x86_64-unknown-linux-gnu` target bundle into a `.deb` with
`dpkg-deb --build` and uploads it to the `cli-v<version>` release (and the
rolling `cli-stable` / `cli-unstable` release) on `beskid_compiler`. It uses the
release job's `compiler_release_token`; see `SECRETS.md`.

No Launchpad account, GPG key, or apt repository is involved. The `.deb` is a
release asset that users download and install with `apt install ./<file>.deb`.

## What the .deb does

The package installs the whole toolchain under the `/usr` prefix so the CLI can
find its runtime kit and corelib from its own executable, with no environment
variables:

- `/usr/bin/beskid`, `/usr/bin/beskid_lsp`, `/usr/bin/beskid-up`
- `/usr/lib/beskid-runtime/abi-5/` (the ABI-v5 runtime kit)
- `/usr/beskid_corelib/`, `/usr/packages/`, and `/usr/release-version.txt`
- `/usr/share/doc/beskid/copyright` and `NOTICE`

`postinst` enforces `0755` on the three binaries and prints a confirmation.
`prerm` is a no-op. `control` declares `Depends: libc6` and
`Architecture: amd64`, and stamps the release version.

## Install (end users)

```sh
# download beskid-<version>-amd64.deb from the cli-v<version> release on beskid_compiler
sudo apt install ./beskid-<version>-amd64.deb
beskid --version
```

`apt install ./<file>.deb` also installs the recommended packages below;
`dpkg -i` does not pull dependencies.

## Building programs needs a C toolchain

`beskid build` and `beskid run` link with the system C compiler driver (`cc`)
and, for static libraries, `ar` and `ranlib`. The package therefore
`Recommends: gcc | c-compiler, libc6-dev`. If you installed with
`--no-install-recommends`, or on a minimal image, add them yourself:

```sh
sudo apt install gcc libc6-dev
```

`beskid test` runs tests in the JIT and does not need them.

## Future: apt repository

If you later want `apt update && apt install beskid`, host the `.deb` in an apt
repository (for example GitHub Pages with a signed `Release` file, or a hosted
service such as Cloudsmith or a Launchpad PPA). The `.deb` produced today is
reusable as is; only the publish target and signing change.
