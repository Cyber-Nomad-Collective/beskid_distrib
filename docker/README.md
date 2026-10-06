# Beskid Docker Images

Sources for two container images built from a verified Beskid target bundle.

> **No pipeline builds these.** Their GitHub Actions lane was removed with the
> retired workflow (superrepo commit `fcde7045`), and the superrepo's Woodpecker
> pipelines only push the five platform images to `cr.beskid-lang.org/beskid/`.
> Build these locally as described below until a Woodpecker lane is added.

## Images

| Image | Description |
|---|---|
| `beskid` (`Dockerfile`) | Complete no-environment toolchain bundle on Debian Bookworm Slim, plus Clang, GCC, binutils and libc development headers for native compilation and linking. |
| `beskid-runner` (`Dockerfile.runner`) | The same bundle plus `curl`, `jq`, `git`, `unzip`, and `gnupg` for CI jobs. |

The bundle is installed at `/opt/beskid`. Its `bin`, ABI-v5 runtime kit,
corelib, packages, and version marker stay under that single prefix, so no
Beskid runtime or corelib environment variables are required.

Both images install the native prerequisites with recommendations disabled.
Clang compiles the target-specific platform/bootstrap objects; `cc` links the
program, and `ar`/`ranlib` build static archives. The runner's final stage copies
the bundle, not the base image's system packages, so it declares these tools
independently.

## Build locally

The Dockerfiles copy a verified bundle from `oci-build/beskid-bundle/` in the
build context and `LICENSE` / `NOTICE` from its root. Fetch the bundle with the
distribution scripts, then build from the superrepo root:

```sh
# GH_TOKEN needs read access on Cyber-Nomad-Collective/beskid_compiler
GH_TOKEN=... bash beskid_distrib/scripts/prepare-container-toolchain.sh \
  <version> oci-build/beskid-bundle

docker build -f beskid_distrib/docker/Dockerfile -t beskid:local .
docker build -f beskid_distrib/docker/Dockerfile.runner \
  --build-arg BESKID_BASE_IMAGE=beskid:local -t beskid-runner:local .
```

Qualify both actual images before publishing them. From the superrepo root:

```sh
for image in beskid:local beskid-runner:local; do
  docker run --network=none --entrypoint bash \
    -v "$PWD/beskid_distrib:/test:ro" "$image" \
    /test/tests/container-toolchain.test.sh <version>
done
```

The test installs nothing and rejects missing native tools. It compiles a
libc-header probe, exercises the linker/archive tools, and analyzes/builds/runs
a project using only the installed bundle. The generated lock must remain
unchanged. The test prints its evidence directory and retains it inside the
stopped container. Neither local image builds nor this test publish images.

`<version>` is `X.Y.Z` or `X.Y.Z-unstable`. `docker-compose.yml` builds the same
two images with the superrepo as the build context:

```sh
cd beskid_distrib/docker
docker compose build
docker compose run beskid --version
```

## Use

```sh
docker run beskid:local --version

# Build a project (mount the workspace)
docker run -v "$(pwd)":/workspace -w /workspace beskid:local build
```
