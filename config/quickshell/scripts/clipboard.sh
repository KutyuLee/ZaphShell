#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-list}"

send_paste() {
    if [ -f "${HOME}/.config/hypr/hyprland.lua" ]; then
        hyprctl dispatch "hl.dsp.exec_raw('sendshortcut CTRL,V,')" >/dev/null 2>&1 || hyprctl dispatch sendshortcut "CTRL,V," >/dev/null 2>&1 || true
    else
        hyprctl dispatch sendshortcut "CTRL,V," >/dev/null 2>&1 || hyprctl dispatch "hl.dsp.exec_raw('sendshortcut CTRL,V,')" >/dev/null 2>&1 || true
    fi
}

case "$CMD" in
    list)
        python3 - <<'PY'
import subprocess, json

items = []
try:
    raw = subprocess.check_output(["cliphist", "list"], stderr=subprocess.DEVNULL).decode("utf-8", errors="replace")
    lines = raw.strip().split("\n")
    for line in lines[:80]:
        if not line:
            continue
        parts = line.split("\t", 1)
        cid = parts[0].strip()
        text = parts[1] if len(parts) > 1 else ""
        is_img = text.startswith("[[ binary data")
        preview = "[Image]" if is_img else text.replace("\n", " ").strip()
        if len(preview) > 120:
            preview = preview[:118] + "…"
        items.append({
            "id": cid,
            "raw": line,
            "text": text,
            "preview": preview,
            "isImage": is_img
        })
except Exception:
    pass

print(json.dumps(items))
PY
        ;;

    copy)
        RAW="${2:-}"
        if [ -n "$RAW" ]; then
            printf '%s' "$RAW" | cliphist decode | wl-copy
        fi
        ;;

    paste)
        RAW="${2:-}"
        if [ -n "$RAW" ]; then
            printf '%s' "$RAW" | cliphist decode | wl-copy
            sleep 0.08
            send_paste
        fi
        ;;

    paste-latest)
        FIRST=$(cliphist list 2>/dev/null | head -n 1 || true)
        if [ -n "$FIRST" ]; then
            printf '%s' "$FIRST" | cliphist decode | wl-copy
            sleep 0.08
            send_paste
        fi
        ;;

    delete)
        RAW="${2:-}"
        if [ -n "$RAW" ]; then
            printf '%s' "$RAW" | cliphist delete
        fi
        ;;

    delete-latest)
        FIRST=$(cliphist list 2>/dev/null | head -n 1 || true)
        if [ -n "$FIRST" ]; then
            printf '%s' "$FIRST" | cliphist delete
        fi
        ;;

    wipe)
        cliphist wipe
        ;;

    *)
        echo "Usage: clipboard.sh {list|copy|paste|paste-latest|delete|delete-latest|wipe}" >&2
        exit 1
        ;;
esac
