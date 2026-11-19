//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "."
import "./components"

ShellRoot {
    id: root

    // Resolve the main monitor (DP-1 Samsung 3440x1440 ultrawide)
    function getMainScreen() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return null;
        for (let i = 0; i < screens.length; ++i) {
            if (screens[i] && screens[i].name === Theme.mainMonitorName) {
                return screens[i];
            }
        }
        return screens[0];
    }

    readonly property var mainScreen: getMainScreen()

    // IPC Handler for Hyprland keybinds
    IpcHandler {
        target: "shell"
        function toggleLauncher() {
            ShellState.toggleLauncher();
        }
        function toggleControlCenter() {
            ShellState.toggleControlCenter();
        }
        function toggleSysMenu() {
            ShellState.toggleSysMenu();
        }
        function toggleWeather() {
            ShellState.toggleWeather();
        }
        function toggleWeatherDebug() {
            ShellState.toggleWeatherDebugMenu();
        }
        function setWeatherDebug(mode: string) {
            ShellState.setWeatherDebugMode(mode);
        }
        function toggleThemeMode() {
            ShellState.toggleThemeMode();
        }
        function dismissNotification() {
            ShellState.dismissNotification();
        }
        function showQuickTab() {
            ShellState.ccActiveTab = 0;
        }
        function showMediaTab() {
            ShellState.ccActiveTab = 1;
        }
        function showAlertsTab() {
            ShellState.notifCenterOpen = true;
        }
        function toggleNotifCenter() {
            ShellState.toggleNotifCenter();
        }
        function toggleNotifications() {
            ShellState.toggleNotifCenter();
        }
        function showNetworkSubmenu() {
            ShellState.ccActiveTab = 0;
            ShellState.networkExtended = true;
            ShellState.bluetoothExtended = false;
            ShellState.audioExtended = false;
        }
        function showBluetoothSubmenu() {
            ShellState.ccActiveTab = 0;
            ShellState.bluetoothExtended = true;
            ShellState.networkExtended = false;
            ShellState.audioExtended = false;
        }
        function showAudioSubmenu() {
            ShellState.ccActiveTab = 0;
            ShellState.audioExtended = true;
            ShellState.networkExtended = false;
            ShellState.bluetoothExtended = false;
        }
        function closeSubmenus() {
            ShellState.networkExtended = false;
            ShellState.bluetoothExtended = false;
            ShellState.audioExtended = false;
        }
        function togglePowerMenu() {
            ShellState.togglePowerOsd();
        }
        function togglePowerOsd() {
            ShellState.togglePowerOsd();
        }
        function toggleClipboard() {
            ShellState.toggleClipboard();
        }
        function toggleCheatSheet() {
            ShellState.toggleCheatSheet();
        }
        function toggleSettings() {
            ShellState.toggleSettings();
        }
        function showScratchpadSettings() {
            ShellState.settingsTab = 4;
            ShellState.settingsOpen = true;
        }
        function showGeneralSettings() {
            ShellState.settingsTab = 0;
            ShellState.settingsOpen = true;
        }
        function nextKeyboardLayout() {
            ShellState.nextKeyboardLayout();
        }
        function toggleTrayMenu() {
            if (ShellState.trayMenuOpen) {
                ShellState.trayMenuOpen = false;
            } else {
                const items = (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : [];
                for (let i = 0; i < items.length; ++i) {
                    if (items[i].hasMenu && items[i].menu) {
                        ShellState.trayMenuSource = items[i].menu;
                        ShellState.trayMenuTitle = items[i].title || items[i].id || "";
                        const screenW = root.mainScreen ? root.mainScreen.width : 1920;
                        ShellState.trayMenuCenterX = Math.max(200, screenW - 415);
                        ShellState.trayMenuRightX = Math.max(300, screenW - 315);
                        ShellState.trayMenuOpen = true;
                        return;
                    }
                }
            }
        }
        function clearNotifs() {
            ShellState.clearAllHistory();
        }
        function dismissFirstNotif() {
            ShellState.dismissFromHistory(0);
        }
        function lock() {
            ShellState.lockScreen();
        }
    }

    // Desktop wallpaper is managed natively by hyprpaper on WlrLayer.Background.
    // Continuous Rounded Screen Frame around the desktop (mapped BEFORE Bar so Bar widgets sit on top!)
    Variants {
        model: Quickshell.screens
        delegate: Component {
            ScreenFrame {
                required property var modelData
                screen: modelData
            }
        }
    }

    property var mainBarWindow: null
    property var barWindowMap: ({})

    function getActiveScreen() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return null;
        for (let i = 0; i < screens.length; ++i) {
            if (screens[i] && screens[i].name === ShellState.activeMonitorName) {
                return screens[i];
            }
        }
        return mainScreen;
    }

    readonly property var activeScreen: getActiveScreen()
    readonly property var activeBarWindow: barWindowMap[ShellState.activeMonitorName] || mainBarWindow

    // Connected Caelestia Top Bar across screens (sits above ScreenFrame)
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {
                id: barInst
                required property var modelData
                screen: modelData
                Component.onCompleted: {
                    if (modelData && modelData.name) {
                        const next = Object.assign({}, root.barWindowMap);
                        next[modelData.name] = barInst;
                        root.barWindowMap = next;
                    }
                    if (modelData === root.mainScreen) {
                        root.mainBarWindow = barInst;
                    }
                }
            }
        }
    }

    // Zero-flicker Hardware-smooth Dimming Overlay across all screens (100% click-through)
    Variants {
        model: Quickshell.screens
        delegate: Component {
            BrightnessOverlay {
                required property var modelData
                screen: modelData
            }
        }
    }


    // Liquid Morphing App Launcher floating out of Center Dynamic Island (active monitor)
    AppLauncher {
        screen: root.activeScreen
    }

    // Liquid Morphing Top-Middle Control Center (active monitor)
    ControlCenter {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Liquid Morphing Top-Right Notification Center (active monitor)
    NotificationCenter {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Liquid Morphing Right Volume Slider OSD (active monitor)
    VolumeOsd {
        screen: root.activeScreen
    }

    // Dynamic Island Keyboard Layout Switch Announcement (active monitor)
    KeyboardOsd {
        screen: root.activeScreen
    }

    // Standalone Liquid Morphing Right Power Menu OSD (active monitor)
    PowerMenuOsd {
        screen: root.activeScreen
    }

    // Liquid Morphing Bottom Clipboard Manager (active monitor)
    ClipboardManager {
        screen: root.activeScreen
    }

    // On-screen Floating Notification Popups (active monitor)
    NotificationPopup {
        screen: root.activeScreen
    }

    // Top-Left macOS-style Arch System Menu (active monitor)
    SystemMenu {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Top-Right Liquid Morphing Weather Panel (active monitor)
    WeatherPanel {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Top-Right Liquid Morphing Calendar Dropdown (active monitor)
    CalendarPanel {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Top-Left Weather State Debug Dropdown (active monitor)
    WeatherDebugPanel {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Top Liquid Morphing System Tray Menu Panel (active monitor)
    TrayMenuPanel {
        screen: root.activeScreen
        barWindow: root.activeBarWindow
    }

    // Keyboard Shortcuts Cheat Sheet Modal Dialog (active monitor)
    CheatSheet {
        screen: root.activeScreen
    }

    // Simplistic Shell Settings Modal Dialog (active monitor)
    SettingsModal {
        screen: root.activeScreen
    }

    // Minimalist Apple/GNOME Lock Screen across all screens
    Variants {
        model: Quickshell.screens
        delegate: Component {
            LockScreen {
                required property var modelData
                screen: modelData
            }
        }
    }
}
