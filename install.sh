#!/usr/bin/env bash
# ==============================================================================
# ZaphShell: Automated Installer (Arch Linux + Hyprland)
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log_info() { echo -e "${BLUE}[i]${RESET} ${BOLD}$1${RESET}"; }
log_success() { echo -e "${GREEN}[+]${RESET} ${BOLD}$1${RESET}"; }
log_warn() { echo -e "${YELLOW}[!]${RESET} ${BOLD}$1${RESET}"; }
log_error() { echo -e "${RED}[x]${RESET} ${BOLD}$1${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.config/quickshell"
HYPR_DIR="${HOME}/.config/hypr"
PICTURES_DIR="${HOME}/Pictures"
MODE=""
AUTO_YES=false

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --copy)
            MODE="copy"
            shift
            ;;
        --symlink)
            MODE="symlink"
            shift
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --symlink    Symlink ~/.config/quickshell to the repo (default for writable checkouts)"
            echo "  --copy       Copy files into ~/.config/quickshell (default for read-only / system installs)"
            echo "  -y, --yes    Skip interactive confirmation prompts"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$MODE" ]; then
    if [ -w "${SCRIPT_DIR}/config/quickshell" ]; then
        MODE="symlink"
    else
        MODE="copy"
    fi
fi

echo -e "${BOLD}====================================================${RESET}"
echo -e "${BOLD}           ZaphShell Installer (v0.3.2)           ${RESET}"
echo -e "${BOLD}====================================================${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Dependency Checks & Auto-Install (Arch Linux)
# ------------------------------------------------------------------------------
log_info "Checking core runtime dependencies..."

DEP_CMDS=(
    "quickshell"
    "hyprctl"
    "hyprpaper"
    "wl-copy"
    "wl-paste"
    "cliphist"
    "playerctl"
    "wpctl"
    "parec"
    "ffmpeg"
    "nmcli"
    "bluetoothctl"
    "grim"
    "slurp"
    "jq"
    "python3"
    "notify-send"
)

DEP_PKGS=(
    "quickshell"
    "hyprland"
    "hyprpaper"
    "wl-clipboard"
    "wl-clipboard"
    "cliphist"
    "playerctl"
    "wireplumber"
    "pipewire-pulse"
    "ffmpeg"
    "networkmanager"
    "bluez-utils"
    "grim"
    "slurp"
    "jq"
    "python"
    "libnotify"
)

MISSING_PKGS=()
for i in "${!DEP_CMDS[@]}"; do
    if ! command -v "${DEP_CMDS[$i]}" >/dev/null 2>&1; then
        pkg="${DEP_PKGS[$i]}"
        if [[ ! " ${MISSING_PKGS[*]} " =~ " ${pkg} " ]]; then
            MISSING_PKGS+=("$pkg")
        fi
    fi
done

if command -v pacman >/dev/null 2>&1; then
    for font_pkg in adwaita-fonts ttf-jetbrains-mono-nerd; do
        if ! pacman -Qq "$font_pkg" >/dev/null 2>&1; then
            MISSING_PKGS+=("$font_pkg")
        fi
    done
fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warn "Missing dependencies: ${MISSING_PKGS[*]}"
    if command -v pacman >/dev/null 2>&1; then
        INSTALL_DEPS=false
        if [ "$AUTO_YES" = true ]; then
            INSTALL_DEPS=true
        else
            read -rp "Install missing dependencies now with pacman? [Y/n]: " dep_ans
            if [[ ! "$dep_ans" =~ ^[Nn]$ ]]; then
                INSTALL_DEPS=true
            fi
        fi

        if [ "$INSTALL_DEPS" = true ]; then
            sudo pacman -S --needed "${MISSING_PKGS[@]}"
            log_success "Installed missing dependencies!"
        else
            log_warn "Continuing without installing missing dependencies."
        fi
    else
        log_error "pacman not found. ZaphShell's automated installer targets Arch Linux."
        exit 1
    fi
else
    log_success "All core runtime dependencies found!"
fi

# ------------------------------------------------------------------------------
# 2. Optional Default Shell Applications
# ------------------------------------------------------------------------------
if [ "$AUTO_YES" = false ]; then
    echo ""
    log_info "Default shell applications:"
    APP_KEYS=(   "kitty"    "firefox"  "thunar"       "btop"           "vscodium"    "discord"       "spotify")
    APP_ROLES=(  "Terminal" "Browser"  "File Manager" "System Monitor" "Code Editor" "Communication" "Music Player")

    is_app_installed() {
        case "$1" in
            vscodium) command -v codium >/dev/null 2>&1 ;;
            spotify)  command -v spotify >/dev/null 2>&1 || command -v spotify-launcher >/dev/null 2>&1 ;;
            *)        command -v "$1" >/dev/null 2>&1 ;;
        esac
    }

    ANY_APP_MISSING=false
    for i in "${!APP_KEYS[@]}"; do
        status_label="${GREEN}installed${RESET}"
        if ! is_app_installed "${APP_KEYS[$i]}"; then
            status_label="${YELLOW}not installed${RESET}"
            ANY_APP_MISSING=true
        fi
        printf "  %d) %-10s (%-14s) [%b]\n" "$((i + 1))" "${APP_KEYS[$i]}" "${APP_ROLES[$i]}" "$status_label"
    done
    echo ""

    if [ "$ANY_APP_MISSING" = true ]; then
        read -rp "Do you want to install any of these default apps? [y/N]: " install_apps_yn
        if [[ "$install_apps_yn" =~ ^[Yy]$ ]]; then
            read -rp "Enter numbers to install (e.g. 1 3 5), 'all', or 'none' [all]: " app_choice
            app_choice="${app_choice:-all}"

            SELECTED_APPS=()
            if [[ "${app_choice,,}" == "all" ]]; then
                SELECTED_APPS=("${APP_KEYS[@]}")
            elif [[ "${app_choice,,}" != "none" ]]; then
                cleaned="${app_choice//,/ }"
                for token in $cleaned; do
                    if [[ "$token" =~ ^[1-7]$ ]]; then
                        SELECTED_APPS+=("${APP_KEYS[$((token - 1))]}")
                    else
                        log_warn "Ignoring unrecognized selection: $token"
                    fi
                done
            fi

            if [ ${#SELECTED_APPS[@]} -gt 0 ]; then
                REPO_PKGS=()
                AUR_PKGS=()

                for app in "${SELECTED_APPS[@]}"; do
                    case "$app" in
                        kitty|firefox|thunar|btop|discord) REPO_PKGS+=("$app") ;;
                        spotify) REPO_PKGS+=("spotify-launcher") ;;
                        vscodium) AUR_PKGS+=("vscodium-bin") ;;
                    esac
                done

                if [ ${#REPO_PKGS[@]} -gt 0 ]; then
                    log_info "Installing official repository apps: ${REPO_PKGS[*]}"
                    sudo pacman -S --needed "${REPO_PKGS[@]}"
                fi

                if [ ${#AUR_PKGS[@]} -gt 0 ]; then
                    AUR_HELPER=""
                    if command -v yay >/dev/null 2>&1; then
                        AUR_HELPER="yay"
                    elif command -v paru >/dev/null 2>&1; then
                        AUR_HELPER="paru"
                    fi

                    if [ -n "$AUR_HELPER" ]; then
                        log_info "Installing AUR apps via ${AUR_HELPER}: ${AUR_PKGS[*]}"
                        "$AUR_HELPER" -S --needed "${AUR_PKGS[@]}"
                    else
                        log_warn "No AUR helper (yay/paru) found for: ${AUR_PKGS[*]}"
                        echo "  Install manually from AUR, e.g.: yay -S ${AUR_PKGS[*]}"
                    fi
                fi
            fi
        fi
    else
        log_success "All default shell apps are already installed."
    fi
fi

# ------------------------------------------------------------------------------
# 3. Wallpapers & Initial Hyprpaper Configuration
# ------------------------------------------------------------------------------
log_info "Setting up wallpapers in ${PICTURES_DIR}/Wallpapers..."
WALLPAPERS_SUBDIR="${PICTURES_DIR}/Wallpapers"
mkdir -p "$WALLPAPERS_SUBDIR"

if [ -f "${SCRIPT_DIR}/assets/wallpapers/light1.jpg" ] && [ ! -f "${WALLPAPERS_SUBDIR}/light1.jpg" ]; then
    cp "${SCRIPT_DIR}/assets/wallpapers/light1.jpg" "${WALLPAPERS_SUBDIR}/light1.jpg"
    log_success "Installed default light1.jpg into Wallpapers folder"
fi

if [ -f "${SCRIPT_DIR}/assets/wallpapers/dark1.jpg" ] && [ ! -f "${WALLPAPERS_SUBDIR}/dark1.jpg" ]; then
    cp "${SCRIPT_DIR}/assets/wallpapers/dark1.jpg" "${WALLPAPERS_SUBDIR}/dark1.jpg"
    log_success "Installed dark1.jpg into Wallpapers folder"
fi

mkdir -p "$HYPR_DIR"
HYPRPAPER_CONF="${HYPR_DIR}/hyprpaper.conf"
if [ ! -f "$HYPRPAPER_CONF" ]; then
    DEFAULT_WALL="${WALLPAPERS_SUBDIR}/light1.jpg"
    if [ ! -f "$DEFAULT_WALL" ] && [ -f "${WALLPAPERS_SUBDIR}/dark1.jpg" ]; then
        DEFAULT_WALL="${WALLPAPERS_SUBDIR}/dark1.jpg"
    fi
    cat > "$HYPRPAPER_CONF" <<HYPRPAPER
preload = ${DEFAULT_WALL}

wallpaper {
    monitor =
    path = ${DEFAULT_WALL}
}

splash = false
HYPRPAPER
    log_success "Created default ${HYPRPAPER_CONF}"
fi

# ------------------------------------------------------------------------------
# 4. Quickshell Configuration Setup
# ------------------------------------------------------------------------------
log_info "Configuring Quickshell destination: ${TARGET_DIR} (mode: ${MODE})..."

if [ -w "${SCRIPT_DIR}/config/quickshell/scripts" ]; then
    chmod +x "${SCRIPT_DIR}/config/quickshell/scripts/"*.sh 2>/dev/null || true
fi

install_quickshell_target() {
    mkdir -p "$(dirname "$TARGET_DIR")"
    if [ "$MODE" = "symlink" ]; then
        ln -s "${SCRIPT_DIR}/config/quickshell" "$TARGET_DIR"
        log_success "Symlinked ${SCRIPT_DIR}/config/quickshell -> ${TARGET_DIR}"
    else
        cp -r "${SCRIPT_DIR}/config/quickshell" "$TARGET_DIR"
        chmod -R u+w "$TARGET_DIR" 2>/dev/null || true
        chmod +x "${TARGET_DIR}/scripts/"*.sh 2>/dev/null || true
        log_success "Copied configuration to ${TARGET_DIR}"
    fi
}

if [ -e "$TARGET_DIR" ] || [ -L "$TARGET_DIR" ]; then
    REAL_TARGET="$(readlink -f "$TARGET_DIR" 2>/dev/null || echo "")"
    REAL_SOURCE="$(readlink -f "${SCRIPT_DIR}/config/quickshell")"

    if [ "$MODE" = "symlink" ] && [ "$REAL_TARGET" = "$REAL_SOURCE" ]; then
        log_success "${TARGET_DIR} is already linked to this repository."
    else
        BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warn "Existing quickshell configuration found. Backing up to ${BACKUP_DIR}..."
        mv "$TARGET_DIR" "$BACKUP_DIR"
        install_quickshell_target
    fi
else
    install_quickshell_target
fi

# ------------------------------------------------------------------------------
# 5. Hyprland Integration
# ------------------------------------------------------------------------------
log_info "Checking Hyprland configuration..."

cp "${SCRIPT_DIR}/config/hypr/quickshell.conf" "${HYPR_DIR}/quickshell.conf"
cp "${SCRIPT_DIR}/config/hypr/quickshell.lua" "${HYPR_DIR}/quickshell.lua"
chmod u+w "${HYPR_DIR}/quickshell.conf" "${HYPR_DIR}/quickshell.lua" 2>/dev/null || true
log_success "Installed Hyprland modules to ${HYPR_DIR}/quickshell.conf and quickshell.lua"

if [ -f "${HYPR_DIR}/hyprland.lua" ]; then
    log_info "Detected Hyprland Lua configuration: ${HYPR_DIR}/hyprland.lua"
    if ! grep -q "quickshell.lua" "${HYPR_DIR}/hyprland.lua" 2>/dev/null; then
        APPLY_LUA=false
        if [ "$AUTO_YES" = true ]; then
            APPLY_LUA=true
        else
            read -rp "Automatically load ZaphShell shortcuts and settings in hyprland.lua? [Y/n]: " lua_hypr
            if [[ "$lua_hypr" =~ ^[Nn]$ ]]; then
                APPLY_LUA=false
            else
                APPLY_LUA=true
            fi
        fi

        if [ "$APPLY_LUA" = true ]; then
            cp "${HYPR_DIR}/hyprland.lua" "${HYPR_DIR}/hyprland.lua.backup.$(date +%Y%m%d_%H%M%S)"
            printf '\n-- ZaphShell Integration\ndofile((os.getenv("HOME") or "") .. "/.config/hypr/quickshell.lua")\n' >> "${HYPR_DIR}/hyprland.lua"
            log_success "Appended ZaphShell integration to hyprland.lua"
        else
            echo -e "  To activate keybindings manually, add to ${BOLD}~/.config/hypr/hyprland.lua${RESET}:"
            echo -e "  ${GREEN}dofile((os.getenv(\"HOME\") or \"\") .. \"/.config/hypr/quickshell.lua\")${RESET}"
        fi
    else
        log_success "hyprland.lua already references quickshell.lua!"
    fi
elif [ -f "${HYPR_DIR}/hyprland.conf" ]; then
    log_info "Detected standard Hyprland configuration: ${HYPR_DIR}/hyprland.conf"
    if ! grep -q "quickshell.conf" "${HYPR_DIR}/hyprland.conf" 2>/dev/null; then
        APPLY_HYPR=false
        if [ "$AUTO_YES" = true ]; then
            APPLY_HYPR=true
        else
            read -rp "Automatically add 'source = ~/.config/hypr/quickshell.conf' to hyprland.conf? [Y/n]: " conf_hypr
            if [[ "$conf_hypr" =~ ^[Nn]$ ]]; then
                APPLY_HYPR=false
            else
                APPLY_HYPR=true
            fi
        fi

        if [ "$APPLY_HYPR" = true ]; then
            cp "${HYPR_DIR}/hyprland.conf" "${HYPR_DIR}/hyprland.conf.backup.$(date +%Y%m%d_%H%M%S)"
            echo "" >> "${HYPR_DIR}/hyprland.conf"
            echo "# ZaphShell Integration" >> "${HYPR_DIR}/hyprland.conf"
            echo "source = ~/.config/hypr/quickshell.conf" >> "${HYPR_DIR}/hyprland.conf"
            log_success "Appended 'source = ~/.config/hypr/quickshell.conf' to hyprland.conf"
        else
            echo -e "  To activate keybindings manually, add to ${BOLD}~/.config/hypr/hyprland.conf${RESET}:"
            echo -e "  ${GREEN}source = ~/.config/hypr/quickshell.conf${RESET}"
        fi
    else
        log_success "hyprland.conf already sources quickshell.conf!"
    fi
else
    if [ -f /usr/share/hypr/hyprland.lua ]; then
        cp /usr/share/hypr/hyprland.lua "${HYPR_DIR}/hyprland.lua"
        printf '\n-- ZaphShell Integration\ndofile((os.getenv("HOME") or "") .. "/.config/hypr/quickshell.lua")\n' >> "${HYPR_DIR}/hyprland.lua"
        log_success "Initialized ${HYPR_DIR}/hyprland.lua with ZaphShell integration"
    else
        printf '# Hyprland configuration\nsource = ~/.config/hypr/quickshell.conf\n' > "${HYPR_DIR}/hyprland.conf"
        log_success "Created ${HYPR_DIR}/hyprland.conf sourcing quickshell.conf"
    fi
fi

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# ------------------------------------------------------------------------------
# 6. Service / Process Management
# ------------------------------------------------------------------------------
echo ""
log_info "Configuring Quickshell user service..."

if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
    QS_BIN="$(command -v quickshell || echo /usr/bin/quickshell)"
    mkdir -p "$USER_SYSTEMD_DIR"
    cat > "${USER_SYSTEMD_DIR}/quickshell-session.service" <<EOF
[Unit]
Description=ZaphShell (Quickshell)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=${QS_BIN} --no-duplicate
KillMode=process
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable quickshell-session.service >/dev/null 2>&1 || true
    pkill -x quickshell 2>/dev/null || true
    sleep 0.3
    systemctl --user restart quickshell-session.service
    log_success "Enabled and started quickshell-session.service (auto-restart on crash)"
elif command -v quickshell >/dev/null 2>&1; then
    pkill -x quickshell 2>/dev/null || true
    sleep 0.5
    nohup quickshell --no-duplicate >/dev/null 2>&1 &
    disown
    log_success "Spawned quickshell process in background."
fi

echo -e "\n${GREEN}${BOLD}ZaphShell installation complete!${RESET}"
echo -e "Key Shortcuts Cheat Sheet:"
echo -e "  - ${BOLD}SUPER${RESET} (press & release) : App Launcher"
echo -e "  - ${BOLD}SUPER + V${RESET}                 : Clipboard Manager"
echo -e "  - ${BOLD}SUPER + N${RESET}                 : Control Center & Notifications"
echo -e "  - ${BOLD}CTRL + ALT + Delete${RESET}       : Power Menu OSD"
echo -e "  - ${BOLD}SUPER + /${RESET}                 : Full Shortcuts Cheat Sheet Grid"
echo -e "  - ${BOLD}SUPER + S / M / D${RESET}         : Scratchpads (Magic / Music / Comm)"
