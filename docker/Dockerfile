FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY oci-build/beskid-bundle/ /opt/beskid/
COPY LICENSE NOTICE /usr/share/licenses/beskid/
RUN chmod 0755 /opt/beskid/bin/beskid /opt/beskid/bin/beskid_lsp /opt/beskid/bin/beskid-up
ENV PATH="/opt/beskid/bin:${PATH}"

LABEL org.opencontainers.image.source="https://github.com/Cyber-Nomad-Collective/beskid" \
      org.opencontainers.image.description="Beskid compiler toolchain with ABI-v5 runtime and corelib" \
      org.opencontainers.image.licenses="Apache-2.0"

ENTRYPOINT ["beskid"]
