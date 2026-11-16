#!/bin/sh
# ttyd runs this once per connected browser tab.
# All tabs attach to the same tmux session => one shared VM console.
if tmux has-session -t minicore 2>/dev/null; then
    exec tmux attach-session -t minicore
fi
echo "Mini Core VM is not running (it was powered off or crashed)."
echo "Restart this service in the Railway dashboard to boot it again."
sleep 30
