#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-dark}"

if [ "$MODE" = "light" ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light' || true
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<GTK3
[Settings]
gtk-application-prefer-dark-theme = false
gtk-theme-name = adw-gtk3
gtk-icon-theme-name = Papirus-Light
GTK3
    cat > "$HOME/.config/gtk-4.0/settings.ini" <<GTK4
[Settings]
gtk-application-prefer-dark-theme = false
gtk-theme-name = adw-gtk3
gtk-icon-theme-name = Papirus-Light
GTK4
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<GTK3
[Settings]
gtk-application-prefer-dark-theme = true
gtk-theme-name = adw-gtk3-dark
gtk-icon-theme-name = Papirus-Dark
GTK3
    cat > "$HOME/.config/gtk-4.0/settings.ini" <<GTK4
[Settings]
gtk-application-prefer-dark-theme = true
gtk-theme-name = adw-gtk3-dark
gtk-icon-theme-name = Papirus-Dark
GTK4
fi
