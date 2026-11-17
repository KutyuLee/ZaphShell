#!/usr/bin/env bash
set -e

MODE="region"
DO_DELAY=0

for arg in "$@"; do
    case "$arg" in
        --delay)
            DO_DELAY=1
            ;;
        --fullscreen)
            MODE="fullscreen"
            ;;
        --region)
            MODE="region"
            ;;
    esac
done

# Delay slightly if requested so any open overlay/panel finishes animating out
if [ "$DO_DELAY" -eq 1 ]; then
    sleep 0.45
fi

# Ensure Pictures/Screenshots directory exists
TARGET_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$TARGET_DIR"

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
FILENAME="Screenshot_${TIMESTAMP}.png"
FILEPATH="$TARGET_DIR/$FILENAME"

HYPRPICKER_PID=""

cleanup() {
    if [ -n "$HYPRPICKER_PID" ]; then
        kill "$HYPRPICKER_PID" 2>/dev/null || true
        wait "$HYPRPICKER_PID" 2>/dev/null || true
        HYPRPICKER_PID=""
    fi
}
trap cleanup EXIT INT TERM

if [ "$MODE" = "fullscreen" ]; then
    # Capture full active desktop
    grim "$FILEPATH"
else
    # Freeze the display during snip selection (similar to Windows Snip & Sketch)
    if command -v hyprpicker >/dev/null 2>&1; then
        hyprpicker -r -z &
        HYPRPICKER_PID=$!
        sleep 0.15
    fi

    # Select rectangular region via slurp with theme-matching glass styling
    GEOM=$(slurp -d -c "#ffffff" -b "#0d101788" -s "#ffffff25" -w 2 2>/dev/null || true)

    if [ -n "$GEOM" ]; then
        grim -g "$GEOM" "$FILEPATH"
    fi

    # Restore screen interactivity immediately
    cleanup
    trap - EXIT INT TERM

    if [ -z "$GEOM" ]; then
        exit 0
    fi
fi

# Verify the file was captured
if [ ! -f "$FILEPATH" ]; then
    exit 0
fi

# Copy image directly to clipboard
if command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$FILEPATH"
fi

# Send notification with thumbnail preview
if command -v notify-send >/dev/null 2>&1; then
    LABEL=$([ "$MODE" = "fullscreen" ] && echo "Fullscreen Screenshot" || echo "Region Screenshot")
    notify-send -a "Screenshot" -i "$FILEPATH" "$LABEL Captured" "Saved to Screenshots/ and copied to clipboard"
fi
