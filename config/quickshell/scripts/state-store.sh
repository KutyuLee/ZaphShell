#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.cache/quickshell"
STATE_FILE="${STATE_DIR}/state.json"

mkdir -p "$STATE_DIR"

MODE="${1:-load}"

if [ "$MODE" = "save" ]; then
    DEFAULT_JSON='{}'
    PAYLOAD="${2:-$DEFAULT_JSON}"
    TMP_FILE="${STATE_FILE}.tmp.$$"
    if command -v jq >/dev/null 2>&1; then
        printf '%s\n' "$PAYLOAD" | jq '.' > "$TMP_FILE" 2>/dev/null || printf '%s\n' "$PAYLOAD" > "$TMP_FILE"
    else
        printf '%s\n' "$PAYLOAD" > "$TMP_FILE"
    fi
    mv -f "$TMP_FILE" "$STATE_FILE"
elif [ "$MODE" = "load" ]; then
    if [ -f "$STATE_FILE" ]; then
        if command -v jq >/dev/null 2>&1; then
            jq -c '.' "$STATE_FILE" 2>/dev/null || tr -d '\n' < "$STATE_FILE"
            printf '\n'
        else
            tr -d '\n' < "$STATE_FILE"
            printf '\n'
        fi
    else
        printf '{}\n'
    fi
fi
