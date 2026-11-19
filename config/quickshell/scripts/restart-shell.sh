#!/usr/bin/env bash
set -euo pipefail

if systemctl --user is-active --quiet quickshell-session.service 2>/dev/null \
   || systemctl --user is-enabled --quiet quickshell-session.service 2>/dev/null; then
    kill_mode="$(systemctl --user show -p KillMode --value quickshell-session.service 2>/dev/null || true)"
    if [ "$kill_mode" = "process" ]; then
        systemctl --user restart quickshell-session.service && exit 0
    else
        # Fallback if unit still uses control-group: only signal main PID so launched apps survive
        systemctl --user kill --kill-whom=main --signal=SIGTERM quickshell-session.service 2>/dev/null || pkill -x quickshell 2>/dev/null || true
        exit 0
    fi
fi

pkill -x quickshell 2>/dev/null || true
sleep 0.25
nohup quickshell --no-duplicate >/dev/null 2>&1 &
