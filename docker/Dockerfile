# ── Stage 1: download the beskid CLI binary from GitHub releases ──
FROM alpine:3.21 AS fetcher

ARG BESKID_VERSION=stable
RUN apk add --no-cache curl

# Resolve CLI download tag from the provided release specifier.
# Accepted values:
# - "stable" for cli-stable
# - "unstable" for cli-unstable
# - any SemVer string (e.g. 0.1.77) for cli-v<version>
RUN if [ "$BESKID_VERSION" = "stable" ]; then \
      TAG="cli-stable"; \
    elif [ "$BESKID_VERSION" = "unstable" ]; then \
      TAG="cli-unstable"; \
    else \
      TAG="cli-v${BESKID_VERSION}"; \
    fi && \
    echo "TAG=$TAG" > /tag.env

RUN . /tag.env && \
    curl -fsSL -o /beskid \
      "https://github.com/Cyber-Nomad-Collective/beskid_compiler/releases/download/${TAG}/beskid-linux-amd64" && \
    chmod +x /beskid

# ── Stage 2: minimal runtime ──
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=fetcher /beskid /usr/local/bin/beskid
COPY beskid_distrib/LICENSE beskid_distrib/NOTICE /usr/share/licenses/beskid/

LABEL org.opencontainers.image.source="https://github.com/Cyber-Nomad-Collective/beskid" \
      org.opencontainers.image.description="Beskid compiler CLI" \
      org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["beskid"]
