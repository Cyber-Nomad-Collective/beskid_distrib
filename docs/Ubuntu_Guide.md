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
- `/usr/beskid_corelib/` (including `packages/`) and `/usr/release-version.txt`
- `/usr/share/doc/beskid/copyright` and `NOTICE`

`postinst` enforces `0755` on the three binaries and prints a confirmation.
`prerm` is a no-op. `control` declares the required native toolchain dependencies
listed below and `Architecture: amd64`, and stamps the release version.

## Install (end users)

```sh
# download beskid-<version>-amd64.deb from the cli-v<version> release on beskid_compiler
sudo apt install ./beskid-<version>-amd64.deb
beskid --version
```

`apt install ./<file>.deb` installs all required dependencies, even with
`--no-install-recommends`. `dpkg -i` does not download missing dependencies;
use `sudo apt --fix-broken install` if needed to finish configuration.

## Building programs needs a C toolchain

`beskid build` and `beskid run` use Clang to compile native platform and
bootstrap objects, then the system C compiler driver (`cc`) to link. Static
libraries also use `ar` and `ranlib`. GCC cannot replace Clang's `-target`
invocation. The DEB therefore declares hard dependencies on `clang`,
`gcc | c-compiler`, `binutils`, `libc6-dev`, and `libc6` rather than relying
on recommendations or a separately configured developer machine.

## Clean installation qualification

Run the regression test on the builder in a fresh Ubuntu 24.04 x86_64 container:

```sh
docker run --name beskid-deb-qualification \
  -v "$PWD:/test:ro" -v "$PWD/output:/input:ro" ubuntu:24.04 \
  bash /test/tests/deb-toolchain-install.test.sh /input/beskid-<version>-amd64.deb
```

The test rejects a preinstalled compiler, installs with recommendations
disabled, exercises Clang's target flag plus `cc`, `ar`, and `ranlib`, and
builds/runs an installed-prefix Beskid project without environment overrides.
Its lockfile must stay unchanged. Retain the container and output as release
evidence; this qualification is separate from metadata-only static tests.

## Future: apt repository

If you later want `apt update && apt install beskid`, host the `.deb` in an apt
repository (for example GitHub Pages with a signed `Release` file, or a hosted
service such as Cloudsmith or a Launchpad PPA). The `.deb` produced today is
reusable as is; only the publish target and signing change.
