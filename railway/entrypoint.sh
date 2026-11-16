#!/bin/sh
# Boots Mini Core once in a tmux session, then serves it as a shared
# web terminal with ttyd. Every browser attaching to the service URL
# sees and controls the SAME console.
set -eu

PORT="${PORT:-8080}"
MEM="${QEMU_MEM:-128}"
SMP="${QEMU_SMP:-1}"
SSH_PORT="${SSH_PORT:-2222}"
DATA_DIR="${DATA_DIR:-/data}"
SESSION="minicore"
BAKED="/opt/mini-core.qcow2"

case "$MEM" in *[!0-9]*|'') echo "[mini-core] QEMU_MEM must be a number (MiB)" >&2; exit 1;; esac
case "$SMP" in *[!0-9]*|'') echo "[mini-core] QEMU_SMP must be a number" >&2; exit 1;; esac
case "$SSH_PORT" in *[!0-9]*|'') echo "[mini-core] SSH_PORT must be a number" >&2; exit 1;; esac

# Optional persistence: if a Railway volume is mounted at $DATA_DIR,
# seed it with the pristine image and use that copy from then on.
IMG="$BAKED"
if [ -d "$DATA_DIR" ]; then
    if [ ! -f "$DATA_DIR/Mini-Core.qcow2" ]; then
        echo "[mini-core] seeding persistent disk copy in $DATA_DIR ..."
        cp "$BAKED" "$DATA_DIR/Mini-Core.qcow2"
    fi
    IMG="$DATA_DIR/Mini-Core.qcow2"
fi

NET="user,id=n0"
if [ "${QEMU_SSH_FWD:-1}" = "1" ]; then
    NET="user,id=n0,hostfwd=tcp:0.0.0.0:${SSH_PORT}-:22"
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[mini-core] booting Mini Core v${MINICORE_VERSION:-0.1.0} (${MEM} MiB RAM, ${SMP} vCPU) ..."
    echo "[mini-core] first boot is slow (software emulation) — the login/setup screen appears after a few minutes."
    tmux new-session -d -s "$SESSION" \
        "qemu-system-x86_64 -nographic -m ${MEM} -smp ${SMP} -drive file=${IMG},format=qcow2,if=virtio -netdev ${NET} -device virtio-net-pci,netdev=n0 -device virtio-rng-pci"
fi

TTYD_ARGS=""
if [ -n "${TTYD_AUTH:-}" ]; then
    TTYD_ARGS="-c ${TTYD_AUTH}"
    echo "[mini-core] terminal is password protected (basic auth)"
fi

echo "[mini-core] web terminal listening on :${PORT}"
echo "[mini-core] keys: Ctrl+A then c = QEMU monitor | Ctrl+A then x = quit QEMU | Ctrl+B then d = detach view"
exec ttyd $TTYD_ARGS -W -p "$PORT" /attach.sh
