FROM debian:bookworm-slim

# Clang compiles native platform objects; cc/binutils link and archive them.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates clang binutils gcc libc6-dev && \
    rm -rf /var/lib/apt/lists/*

COPY oci-build/beskid-bundle/ /opt/beskid/
COPY LICENSE NOTICE /usr/share/licenses/beskid/
RUN test -f /opt/beskid/.beskid-owner.json && \
    chmod 0755 /opt/beskid/bin/beskid /opt/beskid/bin/beskid_lsp /opt/beskid/bin/beskid-up && \
    /opt/beskid/bin/beskid toolchain status | grep -F 'Installation owner: container' 
ENV PATH="/opt/beskid/bin:${PATH}"

LABEL org.opencontainers.image.source="https://github.com/Cyber-Nomad-Collective/beskid" \
      org.opencontainers.image.description="Beskid compiler toolchain with ABI-v5 runtime and corelib" \
      org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["beskid"]
