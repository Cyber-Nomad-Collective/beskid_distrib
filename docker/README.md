# Beskid Docker Images

Sources for two container images built from a verified Beskid target bundle.

> **No pipeline builds these.** Their GitHub Actions lane was removed with the
> retired workflow (superrepo commit `fcde7045`), and the superrepo's Woodpecker
> pipelines only push the five platform images to `cr.beskid-lang.org/beskid/`.
> Build these locally as described below until a Woodpecker lane is added.

## Images

| Image | Description |
|---|---|
| `beskid` (`Dockerfile`) | Complete no-environment toolchain bundle on Debian Bookworm Slim, plus `gcc` and `libc6-dev` so `beskid build` and `beskid run` can link. |
| `beskid-runner` (`Dockerfile.runner`) | The same bundle plus `curl`, `jq`, `git`, `unzip`, and `gnupg` for CI jobs. |

The bundle is installed at `/opt/beskid`. Its `bin`, ABI-v5 runtime kit,
corelib, packages, and version marker stay under that single prefix, so no
Beskid runtime or corelib environment variables are required.

## Build locally

The Dockerfiles copy a verified bundle from `oci-build/beskid-bundle/` in the
build context and `LICENSE` / `NOTICE` from its root. Fetch the bundle with the
distribution scripts, then build from the superrepo root:

```sh
# GH_TOKEN needs read access on Cyber-Nomad-Collective/beskid_compiler
GH_TOKEN=... beskid_distrib/scripts/fetch-release-bundle.sh \
  <version> x86_64-unknown-linux-gnu oci-build/beskid-bundle

docker build -f beskid_distrib/docker/Dockerfile -t beskid:local .
docker build -f beskid_distrib/docker/Dockerfile.runner \
  --build-arg BESKID_BASE_IMAGE=beskid:local -t beskid-runner:local .
```

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
