#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
    exit 1
fi

is_browser() {
    local lower="${1,,}"
    case "$lower" in
        *firefox*|*chromium*|*chrome*|*brave*|*zen*|*vivaldi*|*opera*|*edge*|*librewolf*|*floorp*|*waterfox*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

dedicated_playing=""
dedicated_other=""
browser_playing=""
browser_other=""

while IFS= read -r player; do
    [ -n "$player" ] || continue
    status="$(playerctl -p "$player" status 2>/dev/null || true)"
    if is_browser "$player"; then
        if [ "$status" = "Playing" ]; then
            [ -n "$browser_playing" ] || browser_playing="$player"
        else
            [ -n "$browser_other" ] || browser_other="$player"
        fi
    else
        if [ "$status" = "Playing" ]; then
            [ -n "$dedicated_playing" ] || dedicated_playing="$player"
        else
            [ -n "$dedicated_other" ] || dedicated_other="$player"
        fi
    fi
done < <(playerctl -l 2>/dev/null || true)

target="${dedicated_playing:-${dedicated_other:-${browser_playing:-$browser_other}}}"

if [ -n "$target" ]; then
    exec playerctl -p "$target" "$@"
else
    exec playerctl "$@"
fi
