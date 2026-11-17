#!/usr/bin/env bash
# ==============================================================================
# ChromaShell: Power & Display Idle Action Handler
# Manages DPMS monitor power, systemd inhibition, screen lock, and sleep
# ==============================================================================

ACTION="${1:-}"

case "$ACTION" in
    dpms-off)
        # Turn off display via Hyprland dispatcher (supports both Lua and legacy conf)
        hyprctl dispatch 'hl.dsp.exec_raw("dpms off")' >/dev/null 2>&1 || \
        hyprctl dispatch dpms off >/dev/null 2>&1 || true
        ;;

    dpms-on)
        # Turn on display via Hyprland dispatcher
        hyprctl dispatch 'hl.dsp.exec_raw("dpms on")' >/dev/null 2>&1 || \
        hyprctl dispatch dpms on >/dev/null 2>&1 || true
        ;;

    lock)
        quickshell ipc -n call shell lock >/dev/null 2>&1 || true
        ;;

    suspend)
        systemctl suspend >/dev/null 2>&1 || true
        ;;

    inhibit-start)
        # Start systemd-inhibit for idle so Keep Awake prevents auto-sleep without blocking manual suspend
        pkill -f "systemd-inhibit.*ChromaShell" 2>/dev/null || true
        systemd-inhibit --what=idle --who="ChromaShell" --why="Keep Awake is active" sleep infinity >/dev/null 2>&1 &
        ;;

    inhibit-stop)
        # Stop any active inhibitor
        pkill -f "systemd-inhibit.*ChromaShell" 2>/dev/null || true
        ;;

    *)
        echo "Usage: $0 {dpms-off|dpms-on|lock|suspend|inhibit-start|inhibit-stop}"
        exit 1
        ;;
esac
