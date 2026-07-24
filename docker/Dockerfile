# ── Stage 1: download the beskid CLI binary from GitHub releases ──
FROM alpine:3.21 AS fetcher

ARG BESKID_VERSION=latest
RUN apk add --no-cache curl

# Resolve tag: "latest" → cli-latest, otherwise cli-v<version>
RUN if [ "$BESKID_VERSION" = "latest" ]; then \
      TAG="cli-latest"; \
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

ENTRYPOINT ["beskid"]
