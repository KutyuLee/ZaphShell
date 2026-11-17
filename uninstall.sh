#!/usr/bin/env bash
# ==============================================================================
# ChromaShell: Uninstaller
# Safely removes ChromaShell links and restores previous configuration
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log_info() { echo -e "${BLUE}ℹ ${RESET}${BOLD}$1${RESET}"; }
log_success() { echo -e "${GREEN}✓ ${RESET}${BOLD}$1${RESET}"; }
log_warn() { echo -e "${YELLOW}⚠ ${RESET}${BOLD}$1${RESET}"; }

TARGET_DIR="${HOME}/.config/quickshell"
HYPR_DIR="${HOME}/.config/hypr"

echo -e "${BOLD}====================================================${RESET}"
echo -e "${BOLD}           ChromaShell Uninstaller                  ${RESET}"
echo -e "${BOLD}====================================================${RESET}\n"

# Stop quickshell if running
if systemctl --user is-active quickshell-session >/dev/null 2>&1; then
    log_info "Stopping quickshell-session..."
    systemctl --user stop quickshell-session
elif pgrep -x quickshell >/dev/null 2>&1; then
    log_info "Stopping quickshell process..."
    pkill -x quickshell || true
fi

# Remove quickshell config link/dir
if [ -L "$TARGET_DIR" ]; then
    rm "$TARGET_DIR"
    log_success "Removed symlink ${TARGET_DIR}"
elif [ -d "$TARGET_DIR" ]; then
    read -rp "Remove ${TARGET_DIR}? [y/N]: " confirm_rm
    if [[ "$confirm_rm" =~ ^[Yy]$ ]]; then
        rm -rf "$TARGET_DIR"
        log_success "Removed ${TARGET_DIR}"
    fi
fi

# Check for backups to restore
LATEST_BACKUP=$(ls -td "${TARGET_DIR}.backup."* 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_BACKUP" ] && [ -d "$LATEST_BACKUP" ]; then
    read -rp "Found backup ${LATEST_BACKUP}. Restore it? [Y/n]: " restore_backup
    if [[ ! "$restore_backup" =~ ^[Nn]$ ]]; then
        mv "$LATEST_BACKUP" "$TARGET_DIR"
        log_success "Restored ${TARGET_DIR} from backup!"
    fi
fi

# Clean up hyprland integration
if [ -f "${HYPR_DIR}/hyprland.conf" ]; then
    if grep -q "quickshell.conf" "${HYPR_DIR}/hyprland.conf"; then
        sed -i '/quickshell\.conf/d' "${HYPR_DIR}/hyprland.conf"
        sed -i '/ChromaShell/d' "${HYPR_DIR}/hyprland.conf"
        log_success "Cleaned quickshell references from hyprland.conf"
    fi
fi

rm -f "${HYPR_DIR}/quickshell.conf" "${HYPR_DIR}/quickshell.lua"
log_success "Removed Hyprland modules (${HYPR_DIR}/quickshell.*)"

echo -e "\n${GREEN}Uninstallation finished successfully.${RESET}"
