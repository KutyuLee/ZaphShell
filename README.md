# 🌈 ChromaShell `v0.3.1.1`

A complete, ultra-fluid, morphing desktop environment designed for **Hyprland** using **Quickshell** and **Qt Quick / QML**.

Instead of disconnected, floating rectangular bars, **ChromaShell** wraps your primary monitor in an organic, continuous glass screen border with physical elastic deformations: the Application Launcher and Clipboard Manager physically pull up out of the bottom border, Tray Icon menus and Notification panels morph downwards from the top bar, and Volume / Power OSDs slide out from the right screen boundary with smooth spring physics.

---

## ✨ Features

- **Liquid Frame Geometry**: Continuous obsidian/frosted border around your desktop that organically extends and springs open for panels without abrupt popups or window occlusion.
- **Dynamic Scratchpad Management**: Dedicated scratchpad slots on the top bar for **Magic (`SUPER + S`)**, **System Monitor (`CTRL + SHIFT + Esc`)**, **Music (`SUPER + M`)**, and **Communication (`SUPER + D`)**. Auto-spawns on the active monitor and stays highlighted while active.
- **Liquid Clipboard Manager (`SUPER + V`)**: Floating search pill, instant live search filtering, preview cards, single-clip deletion, and clear all.
- **Glass Control Center (`SUPER + N`)**:
  - Live audio sink switcher and volume control.
  - Interactive Wi-Fi / Network manager.
  - Bluetooth device scanner and connection manager.
  - Display brightness and night light controls.
  - Notification history with dismiss actions.
  - Live local weather card with 5-day forecast.
- **True Dark / Light Mode Crossfade**: Seamless system-wide theme switching updating GTK, Qt, and wallpaper crossfade with zero blue splash artifacts.
- **Settings Modal**: Live customization for scratchpad default apps, wallpaper gallery picker, glass opacity, border thickness, corner rounding, and clock formats.
- **Liquid Power Menu OSD (`CTRL + ALT + Delete`)**: Floats out from the right edge matching the volume slider with Lock, Suspend, Restart, Power Off, and Logout.
- **Interactive Cheat Sheet (`SUPER + /`)**: 3×3 frosted glass grid displaying all system keybindings.

---

## 📦 Requirements & Dependencies

### Core Packages
- **Hyprland** (>= 0.40, tested on 0.57+)
- **Quickshell** (`quickshell` or `quickshell-git`)
- **hyprpaper** (wallpaper daemon)
- **wl-clipboard** (`wl-copy`, `wl-paste`) & **cliphist** (clipboard history)
- **playerctl** (media player control)
- **brightnessctl** (hardware/software backlight control)
- **wireplumber** (`wpctl`) & **pipewire-pulse** (`parec`)
- **ffmpeg** (album art accent sampling)
- **networkmanager** (`nmcli`) & **bluez-utils** (`bluetoothctl`)
- **grim** & **slurp** (screen capture)
- **jq** & **python3**
- **libnotify** (`notify-send`)

### Recommended Fonts & Apps
- **Icons**: `ttf-jetbrains-mono-nerd` or `ttf-nerd-fonts-symbols`
- **UI Font**: `adwaita-fonts`
- **Default Shell Apps**: `kitty`, `firefox`, `thunar`, `btop`, `vscodium`, `discord`, `spotify`

#### Arch Linux / EndeavourOS:
```bash
sudo pacman -S --needed hyprland quickshell hyprpaper wl-clipboard cliphist playerctl brightnessctl wireplumber pipewire-pulse ffmpeg networkmanager bluez-utils grim slurp jq python libnotify adwaita-fonts ttf-jetbrains-mono-nerd
```

#### Fedora:
```bash
sudo dnf install -y hyprland hyprpaper wl-clipboard cliphist playerctl brightnessctl wireplumber pipewire-utils ffmpeg NetworkManager bluez grim slurp jq python3 libnotify adwaita-fonts-all jetbrains-mono-fonts-all
```

---

## 🚀 Installation

### Option 1: AUR (Arch Linux)
Once published to the AUR (`chromashell-git`):
```bash
yay -S chromashell-git
chromashell-setup
```

### Option 2: From Source
Clone and run the automated installer:

```bash
git clone https://github.com/Davidgaming1358/ChromaShell.git ~/ChromaShell
cd ~/ChromaShell
chmod +x install.sh
./install.sh
```

The installer will:
1. Check all required runtime dependencies.
2. Optionally let you install default shell apps (`kitty`, `firefox`, `thunar`, `btop`, `vscodium`, `discord`, `spotify`).
3. Copy default wallpapers (`dark1.jpg`, `light1.jpg`) into `~/Pictures/Wallpapers/` and seed `~/.config/hypr/hyprpaper.conf` if missing.
4. Back up any existing `~/.config/quickshell` and symlink (or copy with `--copy`) the shell configuration.
5. Install Hyprland modules (`~/.config/hypr/quickshell.conf` and `quickshell.lua`).
6. Offer to source the keybindings directly in your `hyprland.conf`.
7. Reload / restart Quickshell.

### Manual Hyprland Integration

If you prefer to include the keybindings manually:

- **For standard `hyprland.conf`**:
  Add this line to `~/.config/hypr/hyprland.conf`:
  ```ini
  source = ~/.config/hypr/quickshell.conf
  ```

- **For Hyprland Lua (`hyprland.lua`)**:
  Add this line to `~/.config/hypr/hyprland.lua`:
  ```lua
  dofile(os.getenv("HOME") .. "/.config/hypr/quickshell.lua")
  ```

---

## ⌨️ Complete Keybindings Cheat Sheet

### 1. Workspace Navigation & Management
| Shortcut | Action |
| :--- | :--- |
| `SUPER + [0-9]` | Switch to Workspace 1–10 |
| `CTRL + SUPER + [0-9]` | Switch to Workspace Group (1-10, 11-20, etc.) |
| `SUPER + ALT + [0-9]` | Move Window to Workspace 1–10 |
| `SUPER + SHIFT + [0-9]` | Move Window to Workspace Silently |
| `CTRL + SUPER + ALT + [0-9]` | Move Window to Workspace Group |
| `SUPER + mouse_down` \| `CTRL + SUPER + Right` \| `SUPER + PgDn` | Next Workspace |
| `SUPER + mouse_up` \| `CTRL + SUPER + Left` \| `SUPER + PgUp` | Previous Workspace |
| `CTRL + SUPER + mouse_down` | Next Workspace Group (+10) |
| `CTRL + SUPER + mouse_up` | Previous Workspace Group (-10) |
| `SUPER + ALT + mouse_down` \| `SUPER + ALT + PgDn` | Move Window to Next Workspace |
| `SUPER + ALT + mouse_up` \| `SUPER + ALT + PgUp` | Move Window to Prev Workspace |
| `SUPER + ALT + S` \| `CTRL + SUPER + SHIFT + Up` | Move Window to Special Workspace |
| `CTRL + SUPER + SHIFT + Down` | Move Window from Special Workspace |

### 2. Special Workspaces (Scratchpads)
| Shortcut | Action | Default Application |
| :--- | :--- | :--- |
| `SUPER + S` | Toggle Special (Magic) Scratchpad | `kitty` |
| `CTRL + SHIFT + Esc` | System Monitor Scratchpad | `kitty -e btop` |
| `SUPER + M` | Music Scratchpad | `spotify` |
| `SUPER + D` | Communication Scratchpad | `discord` |

### 3. Window Actions & Sizing
| Shortcut | Action |
| :--- | :--- |
| `SUPER + Q` | Close Window |
| `SUPER + ALT + Space` | Toggle Window Floating |
| `SUPER + F` | Fullscreen Window |
| `SUPER + ALT + F` | Bordered Fullscreen Window |
| `SUPER + ALT + \` | Picture-in-Picture (PiP floating 480×270 pinned) |
| `SUPER + P` | Pin Window across all workspaces |
| `SUPER + Z` | Move Window Mode (arrows move window, `Esc` or `Enter` exits) |
| `SUPER + X` | Resize Window Mode (arrows resize window, `Esc` or `Enter` exits) |
| `CTRL + SUPER + \` | Center Active Window |
| `CTRL + SUPER + ALT + \` | Normalize Window to 50% 50% and Center |
| `SUPER + -` \| `SUPER + ALT + Left` | Decrease Window Width |
| `SUPER + =` \| `SUPER + ALT + Right` | Increase Window Width |
| `SUPER + SHIFT + -` \| `SUPER + ALT + Up` | Decrease Window Height |
| `SUPER + SHIFT + =` \| `SUPER + ALT + Down` | Increase Window Height |

### 4. Window Groups / Tabbing
| Shortcut | Action |
| :--- | :--- |
| `ALT + Tab` | Cycle Next Window |
| `SHIFT + ALT + Tab` | Cycle Previous Window |
| `CTRL + ALT + Tab` | Cycle Next Window in Active Group |
| `CTRL + SHIFT + ALT + Tab` | Cycle Prev Window in Active Group |
| `SUPER + ,` | Toggle Window Group |
| `SUPER + U` | Ungroup Window (Move out of group) |
| `SUPER + SHIFT + ,` | Lock / Unlock Active Group |

### 5. Applications
| Shortcut | Application |
| :--- | :--- |
| `SUPER + T` | Terminal (`kitty`) |
| `SUPER + W` | Web Browser (`firefox`) |
| `SUPER + C` | Code Editor (`codium`) |
| `SUPER + E` | File Manager (`thunar`) |
| `CTRL + ALT + V` | Audio Volume Control (`pwvucontrol`) |

### 6. Utilities & Capture
| Shortcut | Action |
| :--- | :--- |
| `Print` | Fullscreen Screenshot |
| `SUPER + SHIFT + S` | Interactive Region Screenshot |

### 7. Media & Audio
| Shortcut | Action |
| :--- | :--- |
| `CTRL + SUPER + Space` | Play / Pause Toggle |
| `CTRL + SUPER + =` | Next Track |
| `CTRL + SUPER + -` | Previous Track |
| `CTRL + SUPER + BackSpace` | Stop Playback |
| `SUPER + SHIFT + M` | Mute / Unmute Audio Output |
| `XF86AudioRaiseVolume` | Increase Audio Volume |
| `XF86AudioLowerVolume` | Decrease Audio Volume |
| `XF86MonBrightnessUp` | Increase Display Brightness |
| `XF86MonBrightnessDown` | Decrease Display Brightness |

### 8. Clipboard & Emojis
| Shortcut | Action |
| :--- | :--- |
| `SUPER + V` | Open Liquid Clipboard Manager |
| `SUPER + ALT + V` | Delete Latest Entry from Clipboard |
| `CTRL + SHIFT + ALT + V` | Quick-Paste Latest Clipboard Entry |
| `SUPER + .` | Emoji Picker (`rofi` or `wofi`) |

### 9. System & Interface Controls
| Shortcut | Action |
| :--- | :--- |
| `SUPER` (release) | Open Liquid Application Launcher |
| `SUPER + Space` | Switch Keyboard Layout (with Dynamic Island OSD) |
| `CTRL + ALT + Delete` | Open Liquid Power Menu OSD |
| `SUPER + N` | Open Control Center & Notifications |
| `CTRL + ALT + C` | Clear All Notifications |
| `SUPER + L` \| `SUPER + ALT + L` | Lock Screen |
| `SUPER + SHIFT + L` | Suspend / Sleep System |
| `SUPER + /` \| `SUPER + ?` | Open Keyboard Shortcuts Cheat Sheet |

---

## ⚙️ Configuration & Customization

### Scratchpad Default Applications
Open the shell settings modal (click the gear icon in the top right of the Control Center or click the settings icon on any scratchpad badge), navigate to **Scratchpads**, and edit the command for each scratchpad:
- **Music**: default `spotify`
- **Communication**: default `discord`
- **System Monitor**: default `kitty -e btop`
- **Special**: default `kitty`

Settings are automatically saved in `~/.cache/quickshell/state.json`.

### Multi-Monitor Configuration
By default, the primary liquid frame binds to `DP-1`. If your main monitor is named differently (e.g. `eDP-1`, `HDMI-A-1`), the shell dynamically detects and falls back to your primary display automatically.

You can also explicitly specify your primary display by launching Quickshell with:
```bash
QUICKSHELL_MONITOR="HDMI-A-1" quickshell
```

---

## 🗑️ Uninstallation

To revert to your previous setup:

```bash
cd ~/ChromaShell
./uninstall.sh
```

This will safely remove symlinks, remove Quickshell includes from `hyprland.conf`, and restore your previous `~/.config/quickshell` backup if one was created during installation.

---

## 📄 License
MIT License. Created with Quickshell and Hyprland.
