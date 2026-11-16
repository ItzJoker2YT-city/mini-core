# Mini Core on Railway — QEMU VM behind a shared web terminal (ttyd)
#
# Build context is the repository root; this file lives at railway/Dockerfile
# and is selected by railway.json (build.dockerfilePath).
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        qemu-system-x86 \
        tmux \
    && rm -rf /var/lib/apt/lists/*

# Static ttyd web-terminal binary (musl x86_64)
RUN curl -fsSL -o /usr/local/bin/ttyd \
        https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    && chmod +x /usr/local/bin/ttyd \
    && /usr/local/bin/ttyd --version

# Mini Core disk image, checksum-verified against the official release
ENV MINICORE_VERSION=0.1.0
RUN curl -fsSL -o /tmp/Mini-Core.qcow2 \
        "https://github.com/ItzJoker2YT-city/mini-core/releases/download/v${MINICORE_VERSION}/Mini-Core-v${MINICORE_VERSION}-x86_64.qcow2" \
    && echo "6bbad149c2905a880ea59bb161b99a9586ec5a57db11c58594eacae646dcc4a4  /tmp/Mini-Core.qcow2" | sha256sum -c - \
    && mv /tmp/Mini-Core.qcow2 /opt/mini-core.qcow2

# Normalize line endings (guards against CRLF when files are edited on Windows)
COPY railway/attach.sh railway/entrypoint.sh /
RUN sed -i 's/\r$//' /attach.sh /entrypoint.sh \
    && chmod +x /attach.sh /entrypoint.sh

ENV PORT=8080 \
    QEMU_MEM=128 \
    QEMU_SMP=1 \
    QEMU_SSH_FWD=1 \
    SSH_PORT=2222 \
    DATA_DIR=/data

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
