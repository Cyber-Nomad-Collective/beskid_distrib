# Beskid Docker Images

Pre-built container images for the Beskid CLI, published to GitHub Container Registry
(`ghcr.io/cyber-nomad-collective/beskid`).

## Available images

| Image | Description |
|---|---|
| `beskid:stable` / `beskid:unstable` | Complete no-env toolchain bundle on Debian Bookworm Slim. |
| `beskid:<version>` | Pinned release (e.g. `beskid:0.5.2`). |
| `beskid-runner:stable` / `beskid-runner:unstable` | Beskid + curl, jq, git, unzip, gnupg — for GitHub Actions and CI. |

## Quickstart

```sh
# Show version
docker run ghcr.io/cyber-nomad-collective/beskid:stable --version

# Build a project (mount the workspace)
docker run -v $(pwd):/workspace ghcr.io/cyber-nomad-collective/beskid:stable build

# Pin a specific version
docker run ghcr.io/cyber-nomad-collective/beskid:0.5.2 --version
```

The complete verified target bundle is installed at `/opt/beskid`. Its
`bin`, ABI-v5 runtime kit, corelib, packages, and version marker remain under
that single prefix; no Beskid runtime/corelib environment variables are
required.

## GitHub Actions

```yaml
# Use the container action directly
- uses: docker://ghcr.io/cyber-nomad-collective/beskid:stable
  with:
    args: build

# Or as a step with the runner image (includes curl, jq, git)
- name: Build with Beskid
  run: |
    docker run -v ${{ github.workspace }}:/workspace \
      ghcr.io/cyber-nomad-collective/beskid-runner:stable build
```

## Local testing

```sh
# Build the generic image
docker build -f beskid_distrib/docker/Dockerfile \
  --build-arg BESKID_VERSION=stable \
  -t beskid:local .

# Build the runner image
docker build -f beskid_distrib/docker/Dockerfile.runner \
  --build-arg BESKID_VERSION=stable \
  -t beskid-runner:local .

# Or use docker-compose (see docker-compose.yml)
docker compose -f beskid_distrib/docker/docker-compose.yml up
```

## Docker Compose

`docker-compose.yml` is provided for local development:

```sh
cd beskid_distrib/docker
docker compose build
docker compose run beskid --version
```
