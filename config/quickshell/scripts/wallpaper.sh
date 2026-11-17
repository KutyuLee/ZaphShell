#!/usr/bin/env bash
set -euo pipefail

HYPRPAPER_CONF="${HOME}/.config/hypr/hyprpaper.conf"
WALLPAPERS_DIR="${HOME}/Pictures/Wallpapers"
MODE="${1:-list}"

get_default_wallpaper() {
    if [ -f "${WALLPAPERS_DIR}/light1.jpg" ]; then
        printf '%s' "${WALLPAPERS_DIR}/light1.jpg"
    elif [ -f "${HOME}/Pictures/light1.jpg" ]; then
        printf '%s' "${HOME}/Pictures/light1.jpg"
    elif [ -f "${WALLPAPERS_DIR}/light1.png" ]; then
        printf '%s' "${WALLPAPERS_DIR}/light1.png"
    elif [ -f "${HOME}/Pictures/light1.png" ]; then
        printf '%s' "${HOME}/Pictures/light1.png"
    else
        printf '%s' "${HOME}/Pictures/light1.jpg"
    fi
}

get_current_wallpaper() {
    local target_mon="${1:-}"
    if command -v hyprctl >/dev/null 2>&1; then
        local active_out
        active_out="$(hyprctl hyprpaper listactive 2>/dev/null || true)"
        if [ -n "$active_out" ] && ! printf '%s' "$active_out" | grep -qi "error"; then
            local line=""
            if [ -n "$target_mon" ]; then
                line="$(printf '%s\n' "$active_out" | grep -E "^${target_mon}:" | head -n1 || true)"
            fi
            if [ -z "$line" ]; then
                line="$(printf '%s\n' "$active_out" | grep -E '^[^:]+:[[:space:]]*/' | head -n1 || true)"
            fi
            if [ -n "$line" ]; then
                printf '%s' "${line#*: }" | tr -d '\r\n'
                return
            fi
        fi
    fi

    if [ -f "$HYPRPAPER_CONF" ]; then
        local conf_path
        conf_path="$(grep -E '^[[:space:]]*path[[:space:]]*=' "$HYPRPAPER_CONF" | head -n1 | sed -E 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//' | tr -d '\r\n' || true)"
        if [ -z "$conf_path" ]; then
            conf_path="$(grep -E '^[[:space:]]*wallpaper[[:space:]]*=' "$HYPRPAPER_CONF" | head -n1 | sed -E 's/^[^,]*,[[:space:]]*//' | tr -d '\r\n' || true)"
        fi
        if [ -n "$conf_path" ]; then
            printf '%s' "${conf_path/#\~/$HOME}"
            return
        fi
    fi

    get_default_wallpaper
}

list_wallpapers() {
    local current
    current="$(get_current_wallpaper)"
    mkdir -p "$WALLPAPERS_DIR"

    python3 - "$current" "$WALLPAPERS_DIR" <<'PY'
import sys, os, json, hashlib

current = sys.argv[1] if len(sys.argv) > 1 else ""
wallpapers_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/Pictures/Wallpapers")
exts = {".jpg", ".jpeg", ".png", ".webp"}
items = []
seen_paths = set()
seen_hashes = set()
cur_abs = os.path.abspath(current) if current else ""

def add_candidate(p):
    if not p or not os.path.isfile(p):
        return
    rp = os.path.abspath(p)
    if rp in seen_paths:
        return
    base = os.path.basename(rp)
    low = base.lower()
    _, ext = os.path.splitext(low)
    if ext not in exts:
        return
    try:
        with open(rp, "rb") as f:
            h = hashlib.sha1(f.read(65536)).hexdigest() + "_" + str(os.path.getsize(rp))
    except Exception:
        return
    if h in seen_hashes and rp != cur_abs:
        return
    seen_paths.add(rp)
    seen_hashes.add(h)
    name = os.path.splitext(base)[0].replace("_", " ").replace("-", " ")
    if len(name) > 28:
        name = name[:26] + "…"
    items.append({
        "path": rp,
        "name": name,
        "active": (rp == cur_abs)
    })

if os.path.isdir(wallpapers_dir):
    try:
        entries = sorted(os.listdir(wallpapers_dir), key=lambda s: s.lower())
    except Exception:
        entries = []
    for e in entries:
        full = os.path.join(wallpapers_dir, e)
        if os.path.isfile(full):
            add_candidate(full)

print(json.dumps(items))
PY
}

apply_wallpaper() {
    local target="$1"
    if [ -n "$target" ] && [ -f "$target" ]; then
        MONITORS=()
        if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
            mapfile -t MONITORS < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' || true)
        elif command -v hyprctl >/dev/null 2>&1; then
            mapfile -t MONITORS < <(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}' || true)
        fi
        if [ ${#MONITORS[@]} -eq 0 ]; then
            MONITORS=("")
        fi

        local default_wall
        default_wall="$(get_default_wallpaper)"
        mkdir -p "$(dirname "$HYPRPAPER_CONF")"
        {
            echo "preload = $default_wall"
            if [ "$target" != "$default_wall" ]; then
                echo "preload = $target"
            fi
            echo ""
            for mon in "${MONITORS[@]}"; do
                echo "wallpaper {"
                echo "    monitor = $mon"
                echo "    path = $target"
                echo "}"
                echo ""
            done
            echo "splash = false"
        } > "$HYPRPAPER_CONF"

        if command -v hyprctl >/dev/null 2>&1; then
            if pgrep -x hyprpaper >/dev/null 2>&1; then
                hyprctl hyprpaper preload "$target" >/dev/null 2>&1 || true
                for mon in "${MONITORS[@]}"; do
                    hyprctl hyprpaper wallpaper "${mon},$target" >/dev/null 2>&1 || true
                done
            else
                if [ -f "${HOME}/.config/hypr/hyprland.lua" ]; then
                    hyprctl dispatch "hl.dsp.exec_cmd('hyprpaper')" >/dev/null 2>&1 || hyprctl dispatch exec hyprpaper >/dev/null 2>&1 || true
                else
                    hyprctl dispatch exec hyprpaper >/dev/null 2>&1 || true
                fi
            fi
        fi
    fi
}

if [ "$MODE" = "set" ]; then
    apply_wallpaper "${2:-}"
    list_wallpapers
elif [ "$MODE" = "default" ]; then
    apply_wallpaper "$(get_default_wallpaper)"
    list_wallpapers
elif [ "$MODE" = "current" ]; then
    get_current_wallpaper "${2:-}"
    printf '\n'
else
    list_wallpapers
fi
