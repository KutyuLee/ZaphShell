#!/usr/bin/env bash
# Hardware-safe brightness helper
VAL="$1"
if [ -z "$VAL" ]; then
    exit 0
fi

# Dismiss any stale notification banners in Hyprland
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dismissnotify -1 >/dev/null 2>&1 || true
fi

# Clean up any leftover shader temp files
rm -f "$HOME/.config/hypr/shaders"/tmp_bright_*.frag 2>/dev/null || true

