# Fonts Requirement for ZaphShell

ZaphShell utilizes standard modern sans-serif typography for UI labels and **Nerd Font** glyphs for all indicators, tray badges, media controls, and weather symbols.

### Recommended Fonts:
1. **Icons**: `Symbols Nerd Font` or any patched Nerd Font (e.g. `JetBrains Mono Nerd Font`)
2. **UI Text**: `Inter`, `Cantarell`, `Roboto`, or `Noto Sans`

### Package Names by Distribution:

#### Arch Linux / EndeavourOS / Manjaro:
```bash
sudo pacman -S --needed ttf-jetbrains-mono-nerd inter-font
# or for symbols only:
sudo pacman -S --needed ttf-nerd-fonts-symbols
```

#### Fedora:
```bash
sudo dnf install -y jetbrains-mono-fonts-all google-inter-fonts
```

#### Ubuntu / Debian:
```bash
sudo apt install -y fonts-font-awesome fonts-noto fonts-inter
# Or download Nerd Fonts manually:
mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/SymbolsNerdFont-Regular.ttf https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
fc-cache -fv
```
