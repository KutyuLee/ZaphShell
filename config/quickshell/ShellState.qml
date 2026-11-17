pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "."

Item {
    id: root

    // Central DBus Notification Server
    readonly property alias notifServer: server
    NotificationServer {
        id: server
    }

    // Dynamic Environment & Paths
    readonly property string version: "0.3.1"
    readonly property string userHome: Quickshell.env("HOME") || ""
    readonly property string configDir: userHome + "/.config/quickshell"
    readonly property string scriptsDir: configDir + "/scripts"
    function script(name) { return scriptsDir + "/" + name; }

    function dispatchHypr(luaExpr, stdCmd) {
        const safeLua = String(luaExpr).replace(/'/g, "'\\''");
        Quickshell.execDetached(["sh", "-c",
            "if [ -f \"$HOME/.config/hypr/hyprland.lua\" ]; then hyprctl dispatch '" + safeLua + "' >/dev/null 2>&1 || hyprctl dispatch " + stdCmd + " >/dev/null 2>&1; else hyprctl dispatch " + stdCmd + " >/dev/null 2>&1 || hyprctl dispatch '" + safeLua + "' >/dev/null 2>&1; fi"
        ]);
    }

    FileView {
        id: kernelReleaseFile
        path: "/proc/sys/kernel/osrelease"
    }
    readonly property string kernelVersion: {
        const raw = kernelReleaseFile.text().trim();
        const m = raw.match(/^(\d+\.\d+)/);
        return m ? ("Linux " + m[1]) : "Linux";
    }

    Process {
        id: kbLayoutInitProc
        command: ["hyprctl", "devices", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    const devs = JSON.parse(data);
                    const kbs = devs && devs.keyboards ? devs.keyboards : [];
                    for (let i = 0; i < kbs.length; ++i) {
                        if (kbs[i] && kbs[i].main && kbs[i].active_keymap) {
                            root.activeKeyboardLayout = String(kbs[i].active_keymap);
                            return;
                        }
                    }
                    if (kbs.length > 0 && kbs[0].active_keymap) {
                        root.activeKeyboardLayout = String(kbs[0].active_keymap);
                    }
                } catch (e) {}
            }
        }
    }

    // UI Panel visibility states
    property bool launcherOpen: false
    property bool controlCenterOpen: false
    property bool volumeOsdOpen: false
    property bool kbOsdOpen: false
    property string activeKeyboardLayout: "English (UK)"
    property bool kbSwitchPending: false
    property int kbSwitchSeq: 0
    property bool notifOpen: false
    property bool notifCenterOpen: false
    property bool sysMenuOpen: false
    property bool weatherOpen: false
    property bool trayMenuOpen: false
    property bool settingsOpen: false
    property int settingsTab: 0 // 0: General, 1: Scratchpads
    property bool identifyMonitorsOpen: false
    Timer {
        id: identifyMonitorsTimer
        interval: 2600
        repeat: false
        onTriggered: root.identifyMonitorsOpen = false
    }
    function triggerIdentifyMonitors() {
        root.identifyMonitorsOpen = true;
        identifyMonitorsTimer.restart();
    }
    property bool dndActive: false
    property bool awakeActive: false
    property bool locked: false
    property bool lockVisualOpen: false
    property bool powerMenuOpen: false
    property bool powerOsdOpen: false
    property bool clipboardOpen: false
    property bool networkExtended: false
    property bool bluetoothExtended: false
    property bool audioExtended: false
    property int ccActiveTab: 0 // 0: Quick, 1: Media, 2: Alerts

    // Persistent User Preferences (Synced with ~/.cache/quickshell/state.json)
    property bool use24HourClock: true
    property bool showClockSeconds: false
    property bool showWindowTitle: true
    property bool showBatteryPercent: true
    property bool panelWavesEnabled: true
    property bool liquidGlassEnabled: true
    property bool secondaryFullBar: true
    property bool showDebugButton: true
    property bool musicAppsOnlyOnIsland: true
    property bool announceMediaChanges: true
    property string animationStyle: "relaxed" // "relaxed" | "snappy"
    readonly property bool isSnappyAnimations: animationStyle === "snappy"
    readonly property int animPrimaryEase: isSnappyAnimations ? Easing.OutCubic : Easing.InOutCubic
    function animDur(relaxedMs, snappyMs) {
        return isSnappyAnimations ? snappyMs : relaxedMs;
    }
    onAnimationStyleChanged: scheduleSaveState()
    property real weatherSkyTime: 0.0
    property real weatherSkyIntro: 1.0
    property real weatherSkyProgress: 0.0
    property int notifTimeoutSec: 5
    readonly property string defaultWallpaperPath: root.userHome + "/Pictures/Wallpapers/light1.jpg"
    property string wallpaperPath: defaultWallpaperPath
    property bool stateLoaded: false

    // Configurable Shell Default Applications
    property string terminalApp: "kitty"
    property string fileManagerApp: "thunar"
    property string browserApp: "firefox"
    property string editorApp: "codium"

    onTerminalAppChanged: scheduleSaveState()
    onFileManagerAppChanged: scheduleSaveState()
    onBrowserAppChanged: scheduleSaveState()
    onEditorAppChanged: scheduleSaveState()

    // Configurable Scratchpad Applications
    property string musicApp: "spotify"
    property string commApp: "discord"
    property string sysmonApp: "kitty -e btop"
    property string specialApp: "kitty"

    onMusicAppChanged: scheduleSaveState()
    onCommAppChanged: scheduleSaveState()
    onSysmonAppChanged: scheduleSaveState()
    onSpecialAppChanged: scheduleSaveState()

    function openFolder(dirPath) {
        const dir = String(dirPath || "").trim();
        if (dir.length === 0) return;
        const fm = String(root.fileManagerApp || "thunar").trim();
        const quotedDir = "'" + dir.replace(/'/g, "'\\''") + "'";
        const quotedFm = "'" + fm.replace(/'/g, "'\\''") + "'";
        const term = String(root.terminalApp || "kitty").trim();
        const quotedTerm = "'" + term.replace(/'/g, "'\\''") + "'";
        Quickshell.execDetached([
            "sh", "-c",
            "mkdir -p " + quotedDir + "; "
            + "fm=" + quotedFm + "; "
            + "if [ \"$fm\" = \"yazi\" ] || [ \"$fm\" = \"ranger\" ] || [ \"$fm\" = \"lf\" ]; then "
            + "  exec " + quotedTerm + " -e \"$fm\" " + quotedDir + "; "
            + "elif command -v \"$fm\" >/dev/null 2>&1; then "
            + "  exec \"$fm\" " + quotedDir + "; "
            + "else "
            + "  for candidate in thunar dolphin nautilus nemo pcmanfm xdg-open; do "
            + "    if command -v \"$candidate\" >/dev/null 2>&1; then exec \"$candidate\" " + quotedDir + "; fi; "
            + "  done; "
            + "fi"
        ]);
    }

    function launchTerminal(subCmd) {
        const term = String(root.terminalApp || "kitty").trim();
        const cmd = String(subCmd || "").trim();
        if (cmd.length === 0) {
            Quickshell.execDetached(["sh", "-c", "exec " + term]);
            return;
        }
        const quotedCmd = "'" + cmd.replace(/'/g, "'\\''") + "'";
        if (term === "wezterm") {
            Quickshell.execDetached(["sh", "-c", "exec wezterm start -- sh -c " + quotedCmd]);
        } else {
            Quickshell.execDetached(["sh", "-c", "exec " + term + " -e sh -c " + quotedCmd]);
        }
    }

    function launchDefaultApp(appCmd) {
        const raw = String(appCmd || "").trim();
        if (raw.length === 0) return;
        if (raw === "nvim" || raw === "vim") {
            launchTerminal(raw);
        } else {
            Quickshell.execDetached(["sh", "-c", "exec " + raw]);
        }
    }

    function setXdgDirectoryHandler(fmName) {
        const fm = String(fmName || root.fileManagerApp || "thunar").trim().toLowerCase();
        let desktopFile = fm + ".desktop";
        if (fm === "dolphin") desktopFile = "org.kde.dolphin.desktop";
        else if (fm === "nautilus") desktopFile = "org.gnome.Nautilus.desktop";
        Quickshell.execDetached(["xdg-mime", "default", desktopFile, "inode/directory"]);
    }

    // Power & Display Idle Inactivity Management
    property int screenOffTimeoutMin: 5   // Inactivity minutes to turn off display (0 = never)
    property int sleepTimeoutMin: 15       // Inactivity minutes to suspend system (0 = never)
    property bool lockOnScreenOff: true
    property bool isScreenOff: false

    onAwakeActiveChanged: {
        scheduleSaveState();
        if (awakeActive) {
            Quickshell.execDetached([root.script("power-action.sh"), "inhibit-start"]);
            if (isScreenOff) {
                Quickshell.execDetached([root.script("power-action.sh"), "dpms-on"]);
                isScreenOff = false;
            }
        } else {
            Quickshell.execDetached([root.script("power-action.sh"), "inhibit-stop"]);
        }
    }

    onScreenOffTimeoutMinChanged: scheduleSaveState()
    onSleepTimeoutMinChanged: scheduleSaveState()
    onLockOnScreenOffChanged: scheduleSaveState()

    // 1. Wayland Idle Monitor: Screen Off (turns off monitor via DPMS when idle)
    IdleMonitor {
        id: screenOffIdleMonitor
        timeout: Math.max(10, root.screenOffTimeoutMin * 60)
        respectInhibitors: true
        enabled: !root.awakeActive && root.screenOffTimeoutMin > 0

        onIsIdleChanged: {
            if (isIdle) {
                root.isScreenOff = true;
                if (root.lockOnScreenOff && !root.locked) {
                    root.lockScreen();
                }
                Quickshell.execDetached([root.script("power-action.sh"), "dpms-off"]);
            } else {
                if (root.isScreenOff) {
                    root.isScreenOff = false;
                    Quickshell.execDetached([root.script("power-action.sh"), "dpms-on"]);
                }
            }
        }
    }

    // 2. Wayland Idle Monitor: System Sleep / Suspend
    IdleMonitor {
        id: sleepIdleMonitor
        timeout: Math.max(30, root.sleepTimeoutMin * 60)
        respectInhibitors: true
        enabled: !root.awakeActive && root.sleepTimeoutMin > 0

        onIsIdleChanged: {
            if (isIdle) {
                if (!root.locked) {
                    root.lockScreen();
                }
                Quickshell.execDetached([root.script("power-action.sh"), "suspend"]);
            }
        }
    }

    Process {
        id: hyprpaperQueryProc
        command: [root.script("wallpaper.sh"), "current", Theme.mainMonitorName]
        stdout: SplitParser {
            onRead: data => {
                const p = String(data || "").trim();
                if (p.length > 0 && p !== root.wallpaperPath) {
                    root.wallpaperPath = p;
                }
            }
        }
    }

    function syncWallpaperFromHyprpaper() {
        hyprpaperQueryProc.running = false;
        hyprpaperQueryProc.running = true;
    }

    Timer {
        id: hyprpaperPollTimer
        interval: 8000
        repeat: true
        running: !root.locked
        triggeredOnStart: true
        onTriggered: root.syncWallpaperFromHyprpaper()
    }

    Timer {
        id: hyprpaperSyncTimer
        interval: 50
        repeat: false
        property string pendingWall: ""
        onTriggered: {
            if (pendingWall && pendingWall.length > 0) {
                Quickshell.execDetached([root.script("wallpaper.sh"), "set", pendingWall]);
            }
        }
    }

    function applyWallpaperWithFade(newPath) {
        if (!newPath || newPath.length === 0) return;
        root.wallpaperPath = newPath;
        hyprpaperSyncTimer.pendingWall = newPath;
        hyprpaperSyncTimer.restart();
    }

    function resetWallpaperToDefault() {
        root.wallpaperPath = root.defaultWallpaperPath;
        Quickshell.execDetached([root.script("wallpaper.sh"), "default"]);
        Qt.callLater(syncWallpaperFromHyprpaper);
    }

    function setThemeMode(isLight) {
        if (root.liquidGlassEnabled && isLight) return;
        if (Theme.lightMode === isLight) return;
        Theme.lightMode = isLight;
        Quickshell.execDetached([root.script("theme-mode.sh"), isLight ? "light" : "dark"]);
        root.scheduleSaveState();
    }

    function toggleThemeMode() {
        if (root.liquidGlassEnabled) return;
        root.setThemeMode(!Theme.lightMode);
    }

    property string pendingStateJson: "{}"

    Process {
        id: stateLoadProc
        command: [root.script("state-store.sh"), "load"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim());
                    if (typeof obj.lightMode === "boolean") {
                        Theme.lightMode = obj.lightMode;
                        Quickshell.execDetached([root.script("theme-mode.sh"), obj.lightMode ? "light" : "dark"]);
                    }
                    if (!Quickshell.env("QUICKSHELL_MONITOR") && typeof obj.mainMonitorName === "string" && obj.mainMonitorName.trim().length > 0) Theme.mainMonitorName = obj.mainMonitorName.trim();
                    if (typeof obj.dndActive === "boolean") root.dndActive = obj.dndActive;
                    if (typeof obj.awakeActive === "boolean") root.awakeActive = obj.awakeActive;
                    if (typeof obj.brightness === "number") root.brightness = Math.max(0.15, Math.min(1.0, obj.brightness));
                    if (typeof obj.use24HourClock === "boolean") root.use24HourClock = obj.use24HourClock;
                    if (typeof obj.showClockSeconds === "boolean") root.showClockSeconds = obj.showClockSeconds;
                    if (typeof obj.showWindowTitle === "boolean") root.showWindowTitle = obj.showWindowTitle;
                    if (typeof obj.showBatteryPercent === "boolean") root.showBatteryPercent = obj.showBatteryPercent;
                    if (typeof obj.panelWavesEnabled === "boolean") root.panelWavesEnabled = obj.panelWavesEnabled;
                    if (typeof obj.liquidGlassEnabled === "boolean") root.liquidGlassEnabled = obj.liquidGlassEnabled;
                    if (root.liquidGlassEnabled && Theme.lightMode) {
                        Theme.lightMode = false;
                        Quickshell.execDetached([root.script("theme-mode.sh"), "dark"]);
                    }
                    if (typeof obj.secondaryFullBar === "boolean") root.secondaryFullBar = obj.secondaryFullBar;
                    if (typeof obj.showDebugButton === "boolean") root.showDebugButton = obj.showDebugButton;
                    if (typeof obj.musicAppsOnlyOnIsland === "boolean") root.musicAppsOnlyOnIsland = obj.musicAppsOnlyOnIsland;
                    if (typeof obj.announceMediaChanges === "boolean") root.announceMediaChanges = obj.announceMediaChanges;
                    if (obj.animationStyle === "relaxed" || obj.animationStyle === "snappy") root.animationStyle = obj.animationStyle;
                    if (typeof obj.notifTimeoutSec === "number") root.notifTimeoutSec = Math.max(2, Math.min(15, Math.round(obj.notifTimeoutSec)));
                    if (typeof obj.terminalApp === "string" && obj.terminalApp.trim().length > 0) root.terminalApp = obj.terminalApp.trim();
                    if (typeof obj.fileManagerApp === "string" && obj.fileManagerApp.trim().length > 0) root.fileManagerApp = obj.fileManagerApp.trim();
                    if (typeof obj.browserApp === "string" && obj.browserApp.trim().length > 0) root.browserApp = obj.browserApp.trim();
                    if (typeof obj.editorApp === "string" && obj.editorApp.trim().length > 0) root.editorApp = obj.editorApp.trim();
                    if (typeof obj.musicApp === "string" && obj.musicApp.trim().length > 0) root.musicApp = obj.musicApp.trim();
                    if (typeof obj.commApp === "string" && obj.commApp.trim().length > 0) root.commApp = obj.commApp.trim();
                    if (typeof obj.sysmonApp === "string" && obj.sysmonApp.trim().length > 0) root.sysmonApp = obj.sysmonApp.trim();
                    if (typeof obj.specialApp === "string" && obj.specialApp.trim().length > 0) root.specialApp = obj.specialApp.trim();
                    if (typeof obj.screenOffTimeoutMin === "number") root.screenOffTimeoutMin = Math.max(0, Math.min(60, Math.round(obj.screenOffTimeoutMin)));
                    if (typeof obj.sleepTimeoutMin === "number") root.sleepTimeoutMin = Math.max(0, Math.min(180, Math.round(obj.sleepTimeoutMin)));
                    if (typeof obj.lockOnScreenOff === "boolean") root.lockOnScreenOff = obj.lockOnScreenOff;
                } catch (e) {}
                root.stateLoaded = true;
                root.scheduleSaveState();
            }
        }
    }

    Process {
        id: stateSaveProc
        command: [root.script("state-store.sh"), "save", root.pendingStateJson]
    }

    Timer {
        id: stateSaveTimer
        interval: 150
        repeat: false
        onTriggered: {
            const payload = {
                lightMode: Theme.lightMode,
                mainMonitorName: Theme.mainMonitorName,
                dndActive: root.dndActive,
                awakeActive: root.awakeActive,
                brightness: Number(root.brightness.toFixed(2)),
                use24HourClock: root.use24HourClock,
                showClockSeconds: root.showClockSeconds,
                showWindowTitle: root.showWindowTitle,
                showBatteryPercent: root.showBatteryPercent,
                panelWavesEnabled: root.panelWavesEnabled,
                liquidGlassEnabled: root.liquidGlassEnabled,
                secondaryFullBar: root.secondaryFullBar,
                showDebugButton: root.showDebugButton,
                musicAppsOnlyOnIsland: root.musicAppsOnlyOnIsland,
                announceMediaChanges: root.announceMediaChanges,
                animationStyle: root.animationStyle,
                notifTimeoutSec: root.notifTimeoutSec,
                terminalApp: root.terminalApp,
                fileManagerApp: root.fileManagerApp,
                browserApp: root.browserApp,
                editorApp: root.editorApp,
                musicApp: root.musicApp,
                commApp: root.commApp,
                sysmonApp: root.sysmonApp,
                specialApp: root.specialApp,
                screenOffTimeoutMin: root.screenOffTimeoutMin,
                sleepTimeoutMin: root.sleepTimeoutMin,
                lockOnScreenOff: root.lockOnScreenOff
            };
            root.pendingStateJson = JSON.stringify(payload);
            stateSaveProc.running = false;
            stateSaveProc.running = true;
        }
    }

    function scheduleSaveState() {
        if (!root.stateLoaded) return;
        stateSaveTimer.restart();
    }

    function resetSettingsToDefaults() {
        Theme.frameThickness = 0;
        Theme.mainMonitorName = Quickshell.env("QUICKSHELL_MONITOR") || "DP-1";
        root.use24HourClock = true;
        root.showClockSeconds = false;
        root.showWindowTitle = true;
        root.showBatteryPercent = true;
        root.panelWavesEnabled = true;
        root.liquidGlassEnabled = true;
        root.secondaryFullBar = true;
        root.showDebugButton = true;
        root.musicAppsOnlyOnIsland = true;
        root.announceMediaChanges = true;
        root.animationStyle = "relaxed";
        root.notifTimeoutSec = 5;
        root.dndActive = false;
        root.awakeActive = false;
        root.terminalApp = "kitty";
        root.fileManagerApp = "thunar";
        root.browserApp = "firefox";
        root.editorApp = "codium";
        root.musicApp = "spotify";
        root.commApp = "discord";
        root.sysmonApp = "kitty -e btop";
        root.specialApp = "kitty";
        root.screenOffTimeoutMin = 5;
        root.sleepTimeoutMin = 15;
        root.lockOnScreenOff = true;
        root.setThemeMode(false);
        root.setBrightness(1.0, true);
        root.resetWallpaperToDefault();
        root.scheduleSaveState();
    }

    onDndActiveChanged: scheduleSaveState()
    onUse24HourClockChanged: scheduleSaveState()
    onShowClockSecondsChanged: scheduleSaveState()
    onShowWindowTitleChanged: scheduleSaveState()
    onShowBatteryPercentChanged: scheduleSaveState()
    onPanelWavesEnabledChanged: scheduleSaveState()
    onLiquidGlassEnabledChanged: {
        if (liquidGlassEnabled && Theme.lightMode) {
            setThemeMode(false);
        }
        scheduleSaveState();
    }
    onSecondaryFullBarChanged: scheduleSaveState()
    onShowDebugButtonChanged: scheduleSaveState()
    onMusicAppsOnlyOnIslandChanged: scheduleSaveState()
    onAnnounceMediaChangesChanged: scheduleSaveState()
    onNotifTimeoutSecChanged: scheduleSaveState()

    Connections {
        target: Theme
        function onLightModeChanged() { root.scheduleSaveState(); }
        function onFrameThicknessChanged() { root.scheduleSaveState(); }
        function onMainMonitorNameChanged() { root.scheduleSaveState(); }
    }

    function syncHyprlandWindowGaps() {
        const m = Theme.barMarginX;
        Quickshell.execDetached(["sh", "-c",
            "if [ -f \"$HOME/.config/hypr/hyprland.lua\" ]; then hyprctl dispatch \"function() hl.config({ general = { gaps_out = { top = 10, right = " + m + ", bottom = " + m + ", left = " + m + " } } }) end\" >/dev/null 2>&1 || hyprctl keyword general:gaps_out \"10, " + m + ", " + m + ", " + m + "\" >/dev/null 2>&1; else hyprctl keyword general:gaps_out \"10, " + m + ", " + m + ", " + m + "\" >/dev/null 2>&1; fi || true"
        ]);
    }

    Component.onCompleted: {
        stateLoadProc.running = true;
        weatherFetchProc.running = true;
        kbLayoutInitProc.running = true;
        syncHyprlandWindowGaps();
    }

    // Live Weather State (Populated via scripts/weather.sh)
    property string weatherCity: "Local"
    property string weatherTemp: "--°C"
    property string weatherTempShort: "--°"
    property string weatherFeelsLike: "--°C"
    property string weatherHumidity: "--%"
    property string weatherWind: "-- km/h"
    property string rawWeatherIcon: "󰖐"
    property string rawWeatherDesc: "Loading..."
    property string weatherDebugMode: ""
    readonly property string weatherIcon: {
        switch (weatherDebugMode) {
            case "clear": return "󰖙";
            case "partlyCloudy": return "󰖕";
            case "cloudy": return "󰖐";
            case "rain": return "󰖗";
            case "storm": return "󰖓";
            case "snow": return "󰖘";
            case "fog": return "󰖑";
            default: return rawWeatherIcon;
        }
    }
    readonly property string weatherDesc: {
        switch (weatherDebugMode) {
            case "clear": return "Clear Sky";
            case "partlyCloudy": return "Partly Cloudy";
            case "cloudy": return "Cloudy";
            case "rain": return "Rain";
            case "storm": return "Thunderstorm";
            case "snow": return "Snow";
            case "fog": return "Foggy";
            default: return rawWeatherDesc;
        }
    }
    property string weatherHigh: "--°"
    property string weatherLow: "--°"
    property var weatherHourly: [
        { time: "Now", icon: "󰖐", desc: "Cloudy", temp: "6°" },
        { time: "23:00", icon: "󰖐", desc: "Cloudy", temp: "6°" },
        { time: "00:00", icon: "󰖐", desc: "Cloudy", temp: "6°" },
        { time: "01:00", icon: "󰖐", desc: "Cloudy", temp: "6°" },
        { time: "02:00", icon: "󰼳", desc: "Light Drizzle", temp: "6°" }
    ]
    property var weatherForecast: []
    property bool weatherForceRefresh: false

    // Weather State Debug Menu (Compact floating dropdown next to the notification test button)
    property bool weatherDebugOpen: false
    property real weatherDebugCenterX: 300
    readonly property real weatherDebugTargetWidth: 184
    readonly property real weatherDebugTargetHeight: 304
    property real weatherDebugWidth: 44
    property real weatherDebugHeight: 0
    property real smoothWeatherDebugHeight: weatherDebugOpen ? weatherDebugTargetHeight : 0
    Behavior on smoothWeatherDebugHeight { NumberAnimation { duration: root.animDur(360, 260); easing.type: root.animPrimaryEase } }
    readonly property real weatherDebugDeformScaleY: Math.max(0.86, Math.min(1.12, weatherDebugHeight / Math.max(1, smoothWeatherDebugHeight)))

    ParallelAnimation {
        id: weatherDebugOpenAnim
        alwaysRunToEnd: false
        SequentialAnimation {
            NumberAnimation { target: root; property: "weatherDebugWidth"; to: root.weatherDebugTargetWidth * (root.isSnappyAnimations ? 1.018 : 1.014); duration: root.animDur(320, 235); easing.type: root.animPrimaryEase }
            NumberAnimation { target: root; property: "weatherDebugWidth"; to: root.weatherDebugTargetWidth; duration: root.animDur(220, 160); easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "weatherDebugHeight"; to: root.weatherDebugTargetHeight * (root.isSnappyAnimations ? 1.022 : 1.016); duration: root.animDur(340, 250); easing.type: root.animPrimaryEase }
            NumberAnimation { target: root; property: "weatherDebugHeight"; to: root.weatherDebugTargetHeight; duration: root.animDur(220, 160); easing.type: Easing.InOutSine }
        }
    }

    ParallelAnimation {
        id: weatherDebugCloseAnim
        alwaysRunToEnd: false
        NumberAnimation { id: wdCloseW; target: root; property: "weatherDebugWidth"; to: 44; duration: root.animDur(290, 190); easing.type: Easing.InOutCubic }
        NumberAnimation { id: wdCloseH; target: root; property: "weatherDebugHeight"; to: 0; duration: root.animDur(290, 190); easing.type: Easing.InOutCubic }
    }

    onWeatherDebugOpenChanged: {
        if (weatherDebugOpen) {
            sysMenuOpen = false;
            trayMenuOpen = false;
            launcherOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            weatherDebugCloseAnim.stop();
            if (weatherDebugHeight <= 1) {
                weatherDebugWidth = 44;
                weatherDebugHeight = 0;
            }
            weatherDebugOpenAnim.restart();
        } else {
            weatherDebugOpenAnim.stop();
            wdCloseW.from = weatherDebugWidth;
            wdCloseH.from = weatherDebugHeight;
            weatherDebugCloseAnim.restart();
        }
    }

    function toggleWeatherDebugMenu() {
        if (!weatherDebugOpen) activateFocusedMonitorIfIdle();
        weatherDebugOpen = !weatherDebugOpen;
    }

    function setWeatherDebugMode(mode) {
        activateFocusedMonitorIfIdle();
        weatherDebugMode = mode || "";
        weatherOpen = true;
    }

    Process {
        id: weatherFetchProc
        command: root.weatherForceRefresh
            ? [root.script("weather.sh"), "--force"]
            : [root.script("weather.sh")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const obj = JSON.parse(data.trim());
                    if (obj.city) root.weatherCity = obj.city;
                    if (obj.temp) root.weatherTemp = obj.temp;
                    if (obj.tempShort) root.weatherTempShort = obj.tempShort;
                    if (obj.feelsLike) root.weatherFeelsLike = obj.feelsLike;
                    if (obj.humidity) root.weatherHumidity = obj.humidity;
                    if (obj.wind) root.weatherWind = obj.wind;
                    if (obj.icon) root.rawWeatherIcon = obj.icon;
                    if (obj.desc) root.rawWeatherDesc = obj.desc;
                    if (obj.high) root.weatherHigh = obj.high;
                    if (obj.low) root.weatherLow = obj.low;
                    if (Array.isArray(obj.hourly) && obj.hourly.length > 0) root.weatherHourly = obj.hourly;
                    if (Array.isArray(obj.forecast)) root.weatherForecast = obj.forecast;
                } catch (e) {}
                root.weatherForceRefresh = false;
            }
        }
    }

    Timer {
        id: weatherPeriodicTimer
        interval: 600000 // Refresh every 10 minutes
        running: true
        repeat: true
        onTriggered: {
            root.weatherForceRefresh = false;
            weatherFetchProc.running = false;
            weatherFetchProc.running = true;
        }
    }

    function refreshWeather() {
        root.weatherForceRefresh = true;
        weatherFetchProc.running = false;
        weatherFetchProc.running = true;
    }

    readonly property real targetCcHeight: {
        if (ccActiveTab === 1) {
            return 268; // Compact landscape Media view
        } else {
            if (networkExtended || bluetoothExtended || audioExtended) {
                return 440;
            }
            // Compact landscape Quick Settings view
            return Theme.ccCardHeight;
        }
    }

    NumberAnimation {
        id: ccHeightAdaptAnim
        target: root
        property: "ccHeight"
        duration: root.animDur(360, 260)
        easing.type: root.animPrimaryEase
    }

    onTargetCcHeightChanged: {
        if (controlCenterOpen && !ccOpenAnim.running && !ccCloseAnim.running) {
            ccHeightAdaptAnim.stop();
            ccHeightAdaptAnim.to = targetCcHeight;
            ccHeightAdaptAnim.restart();
        }
    }

    readonly property real targetNotifCenterHeight: notifHistoryModel.count > 0 ? Theme.notifCenterHeight : 154

    onTargetNotifCenterHeightChanged: {
        if (notifCenterOpen) {
            triggerRightIslandMorph();
        }
    }

    // Live notification properties with reactive bindings
    property string notifSummary: ""
    property string notifBody: ""
    property string notifAppName: ""
    property string notifAppIcon: ""
    property string notifImage: ""
    property string notifIconSrc: ""
    property bool notifIsFileImg: false

    // Shared animated morph dimensions driven by realistic dampened harmonic spring oscillations
    // Primary axes
    property real ccHeight: 0
    property real volumeOsdWidth: 0
    property real notifHeight: 0
    property real trayMenuTargetHeight: 180
    property real trayMenuTargetWidth: 160
    property real trayMenuRightX: 3000
    property real trayMenuCenterX: 3000
    property var trayMenuSource: null
    property string trayMenuTitle: ""

    // Standalone Power Menu OSD dimensions (Right edge extrusion)
    property real powerOsdWidth: 0
    property real powerOsdHeight: 330

    // Dynamic cross-axis dimensions (Poisson 2D elastic border bounce)
    property real ccWidth: 0
    property real volumeHeight: Theme.volumeOsdHeight
    property real notifWidth: 0

    // ================= 3 MORPHING BAR ISLANDS + DYNAMIC ISLAND GEOMETRY =================
    property real leftIslandBaseWidth: 230
    property real centerIslandBaseWidth: 210
    property real rightIslandBaseWidth: 310
    property real archLogoBarX: 14

    // Dynamic Album Art Accent Color (matched from currently playing cover art for the waveform & Now Playing label)
    property color mediaArtColor: "#F4F4F6"
    Behavior on mediaArtColor { ColorAnimation { duration: 420; easing.type: Easing.OutCubic } }
    property string pendingArtUrl: ""

    function isBrowserMprisPlayer(p) {
        if (!p) return false;
        const id = String(p.identity || "").toLowerCase();
        const desk = String(p.desktopEntry || "").toLowerCase();
        const dbus = String(p.dbusName || "").toLowerCase();
        const hay = id + " " + desk + " " + dbus;
        return hay.indexOf("firefox") !== -1
            || hay.indexOf("chromium") !== -1
            || hay.indexOf("chrome") !== -1
            || hay.indexOf("brave") !== -1
            || hay.indexOf("zen") !== -1
            || hay.indexOf("vivaldi") !== -1
            || hay.indexOf("opera") !== -1
            || hay.indexOf("edge") !== -1
            || hay.indexOf("librewolf") !== -1
            || hay.indexOf("floorp") !== -1
            || hay.indexOf("waterfox") !== -1;
    }

    function selectIslandMediaPlayer(requirePlaying) {
        const list = (Mpris.players && Mpris.players.values) ? Mpris.players.values : [];
        if (!list || list.length === 0) return null;

        let firstDedicatedPaused = null;
        let firstBrowserPlaying = null;
        let firstBrowserPaused = null;

        for (let i = 0; i < list.length; ++i) {
            const p = list[i];
            if (!p) continue;
            const isBrowser = isBrowserMprisPlayer(p);
            const isPlaying = (p.playbackState === MprisPlaybackState.Playing);

            if (!isBrowser) {
                if (isPlaying) return p;
                if (!firstDedicatedPaused) firstDedicatedPaused = p;
            } else if (!root.musicAppsOnlyOnIsland) {
                if (isPlaying && !firstBrowserPlaying) firstBrowserPlaying = p;
                if (!isPlaying && !firstBrowserPaused) firstBrowserPaused = p;
            }
        }

        if (firstBrowserPlaying) return firstBrowserPlaying;
        if (requirePlaying) return null;
        return firstDedicatedPaused || firstBrowserPaused;
    }

    function orderedMediaPlayers() {
        const list = (Mpris.players && Mpris.players.values) ? Mpris.players.values : [];
        if (!list || list.length === 0) return [];
        const dedicatedPlaying = [];
        const dedicatedPaused = [];
        const browserPlaying = [];
        const browserPaused = [];
        for (let i = 0; i < list.length; ++i) {
            const p = list[i];
            if (!p) continue;
            const isBrowser = isBrowserMprisPlayer(p);
            const isPlaying = (p.playbackState === MprisPlaybackState.Playing);
            if (!isBrowser) {
                if (isPlaying) dedicatedPlaying.push(p);
                else dedicatedPaused.push(p);
            } else {
                if (isPlaying) browserPlaying.push(p);
                else browserPaused.push(p);
            }
        }
        return dedicatedPlaying.concat(dedicatedPaused, browserPlaying, browserPaused);
    }

    function isMprisPlayerPresent(player) {
        if (!player) return false;
        const list = (Mpris.players && Mpris.players.values) ? Mpris.players.values : [];
        if (!list || list.length === 0) return false;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] === player) {
                if (root.musicAppsOnlyOnIsland && root.isBrowserMprisPlayer(player)) return false;
                return true;
            }
        }
        return false;
    }

    property var lastActiveMediaPlayer: null
    property bool mediaPauseHoldActive: false

    Timer {
        id: mediaPauseHoldTimer
        interval: 300000 // 5 minutes
        repeat: false
        Component.onCompleted: {
            if (root.playingIslandPlayer) {
                root.lastActiveMediaPlayer = root.playingIslandPlayer;
            }
        }
        onTriggered: {
            root.mediaPauseHoldActive = false;
            root.lastActiveMediaPlayer = null;
        }
    }

    readonly property var playingIslandPlayer: selectIslandMediaPlayer(true)
    readonly property var islandMediaPlayer: {
        if (root.playingIslandPlayer) return root.playingIslandPlayer;
        if (root.mediaPauseHoldActive && isMprisPlayerPresent(root.lastActiveMediaPlayer)) {
            return root.lastActiveMediaPlayer;
        }
        return null;
    }
    readonly property bool showMediaOnIsland: islandMediaPlayer !== null

    onPlayingIslandPlayerChanged: {
        if (root.playingIslandPlayer) {
            mediaPauseHoldTimer.stop();
            root.lastActiveMediaPlayer = root.playingIslandPlayer;
            root.mediaPauseHoldActive = false;
        } else if (isMprisPlayerPresent(root.lastActiveMediaPlayer)) {
            root.mediaPauseHoldActive = true;
            mediaPauseHoldTimer.restart();
        } else {
            mediaPauseHoldTimer.stop();
            root.mediaPauseHoldActive = false;
            root.lastActiveMediaPlayer = null;
        }
    }

    onIslandMediaPlayerChanged: {
        if (!root.islandMediaPlayer && root.mediaPauseHoldActive) {
            mediaPauseHoldTimer.stop();
            root.mediaPauseHoldActive = false;
            root.lastActiveMediaPlayer = null;
        }
    }

    // Live 5-band PipeWire/Pulse audio spectrum levels for the Dynamic Island visualizer (0.0 .. 1.0)
    readonly property bool isAnyMediaPlaying: playingIslandPlayer !== null

    property real waveB0: 0.0
    property real waveB1: 0.0
    property real waveB2: 0.0
    property real waveB3: 0.0
    property real waveB4: 0.0

    Behavior on waveB0 { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
    Behavior on waveB1 { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
    Behavior on waveB2 { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
    Behavior on waveB3 { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }
    Behavior on waveB4 { NumberAnimation { duration: 85; easing.type: Easing.OutCubic } }

    function waveBand(idx) {
        switch (idx) {
            case 0: return waveB0;
            case 1: return waveB1;
            case 2: return waveB2;
            case 3: return waveB3;
            default: return waveB4;
        }
    }

    ParallelAnimation {
        id: waveIdleDecayAnim
        NumberAnimation { target: root; property: "waveB0"; to: 0.0; duration: 340; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "waveB1"; to: 0.0; duration: 340; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "waveB2"; to: 0.0; duration: 340; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "waveB3"; to: 0.0; duration: 340; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "waveB4"; to: 0.0; duration: 340; easing.type: Easing.OutCubic }
    }

    Timer {
        id: waveStopTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (!root.isAnyMediaPlaying) {
                audioSpectrumProc.running = false;
            }
        }
    }

    onIsAnyMediaPlayingChanged: {
        if (root.isAnyMediaPlaying) {
            waveStopTimer.stop();
            waveIdleDecayAnim.stop();
            if (!audioSpectrumProc.running) {
                audioSpectrumProc.running = true;
            }
        } else {
            waveIdleDecayAnim.restart();
            waveStopTimer.restart();
        }
    }

    Process {
        id: audioSpectrumProc
        command: [root.script("audio-spectrum.sh")]
        running: root.isAnyMediaPlaying
        stdout: SplitParser {
            onRead: data => {
                if (!root.isAnyMediaPlaying) return;
                const parts = data.trim().split(/\s+/);
                if (parts.length < 5) return;
                const v0 = parseFloat(parts[0]);
                const v1 = parseFloat(parts[1]);
                const v2 = parseFloat(parts[2]);
                const v3 = parseFloat(parts[3]);
                const v4 = parseFloat(parts[4]);
                if (!isNaN(v0)) root.waveB0 = Math.max(0.0, Math.min(1.0, v0));
                if (!isNaN(v1)) root.waveB1 = Math.max(0.0, Math.min(1.0, v1));
                if (!isNaN(v2)) root.waveB2 = Math.max(0.0, Math.min(1.0, v2));
                if (!isNaN(v3)) root.waveB3 = Math.max(0.0, Math.min(1.0, v3));
                if (!isNaN(v4)) root.waveB4 = Math.max(0.0, Math.min(1.0, v4));
            }
        }
    }

    // Shared Track-Switch Animation State (360° 3D Album Art Spin + Smooth Title/Artist Crossfade)
    property string displayedTrackTitle: ""
    property string displayedTrackArtist: ""
    property string displayedTrackArtUrl: ""
    property string pendingTrackTitle: ""
    property string pendingTrackArtist: ""
    property string pendingTrackArtUrl: ""
    property real trackSwitchTextOpacity: 1.0
    property real trackSwitchTextOffsetY: 0.0
    property real albumArtSpinAngle: 0.0
    property bool trackArtSwapped: false

    ParallelAnimation {
        id: trackSwitchAnim

        // 1. 180-Degree 3D Album Art Flip (swaps cover texture & accent color at 90° edge-on)
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "albumArtSpinAngle"
                from: 0
                to: 90
                duration: root.animDur(190, 145)
                easing.type: Easing.InCubic
            }
            ScriptAction {
                script: {
                    root.trackArtSwapped = true;
                    root.displayedTrackArtUrl = root.pendingTrackArtUrl;
                    root.extractAlbumArtColor(root.pendingTrackArtUrl);
                }
            }
            NumberAnimation {
                target: root
                property: "albumArtSpinAngle"
                from: 90
                to: 180
                duration: root.animDur(265, 215)
                easing.type: Easing.OutCubic
            }
            PropertyAction {
                target: root
                property: "albumArtSpinAngle"
                value: 0
            }
        }

        // 2. Smooth Title & Artist Crossfade + Single Gentle Settle
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "trackSwitchTextOpacity"
                to: 0.0
                duration: root.animDur(180, 135)
                easing.type: Easing.InCubic
            }
            ScriptAction {
                script: {
                    root.displayedTrackTitle = root.pendingTrackTitle;
                    root.displayedTrackArtist = root.pendingTrackArtist;
                    root.trackSwitchTextOffsetY = 3.5;
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    target: root
                    property: "trackSwitchTextOpacity"
                    to: 1.0
                    duration: root.animDur(275, 225)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: root
                    property: "trackSwitchTextOffsetY"
                    to: 0
                    duration: root.animDur(275, 225)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    SequentialAnimation {
        id: artOnlySwitchAnim

        NumberAnimation {
            target: root
            property: "albumArtSpinAngle"
            from: 0
            to: 90
            duration: root.animDur(190, 145)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.trackArtSwapped = true;
                root.displayedTrackArtUrl = root.pendingTrackArtUrl;
                root.extractAlbumArtColor(root.pendingTrackArtUrl);
            }
        }
        NumberAnimation {
            target: root
            property: "albumArtSpinAngle"
            from: 90
            to: 180
            duration: root.animDur(265, 215)
            easing.type: Easing.OutCubic
        }
        PropertyAction {
            target: root
            property: "albumArtSpinAngle"
            value: 0
        }
    }

    function updateTrackMetadata(title, artist, artUrl, animate) {
        const cleanTitle = title || "";
        const cleanArtist = artist || "";
        const cleanArt = artUrl || "";
        if (!animate || root.displayedTrackTitle.length === 0 || cleanTitle.length === 0) {
            trackSwitchAnim.stop();
            artOnlySwitchAnim.stop();
            root.trackArtSwapped = false;
            root.displayedTrackTitle = cleanTitle;
            root.displayedTrackArtist = cleanArtist;
            root.displayedTrackArtUrl = cleanArt;
            root.pendingTrackTitle = cleanTitle;
            root.pendingTrackArtist = cleanArtist;
            root.pendingTrackArtUrl = cleanArt;
            root.trackSwitchTextOpacity = 1.0;
            root.trackSwitchTextOffsetY = 0.0;
            root.albumArtSpinAngle = 0.0;
            root.extractAlbumArtColor(cleanArt);
            return;
        }
        if (trackSwitchAnim.running && cleanTitle === root.pendingTrackTitle) {
            root.pendingTrackArtist = cleanArtist;
            if (!root.trackArtSwapped) {
                root.pendingTrackArtUrl = cleanArt;
            } else if (cleanArt !== root.displayedTrackArtUrl) {
                root.trackArtSwapped = false;
                root.pendingTrackArtUrl = cleanArt;
                trackSwitchAnim.stop();
                root.displayedTrackTitle = root.pendingTrackTitle;
                root.displayedTrackArtist = root.pendingTrackArtist;
                root.trackSwitchTextOpacity = 1.0;
                root.trackSwitchTextOffsetY = 0.0;
                artOnlySwitchAnim.restart();
            }
            return;
        }
        if (cleanTitle === root.displayedTrackTitle) {
            root.displayedTrackArtist = cleanArtist;
            if (cleanArt !== root.displayedTrackArtUrl && !(artOnlySwitchAnim.running && cleanArt === root.pendingTrackArtUrl)) {
                root.trackArtSwapped = false;
                root.pendingTrackArtUrl = cleanArt;
                artOnlySwitchAnim.restart();
            }
            return;
        }
        artOnlySwitchAnim.stop();
        root.trackArtSwapped = false;
        root.pendingTrackTitle = cleanTitle;
        root.pendingTrackArtist = cleanArtist;
        root.pendingTrackArtUrl = cleanArt;
        trackSwitchAnim.restart();
    }

    Process {
        id: albumColorProc
        command: [root.script("album-color.sh"), root.pendingArtUrl]
        stdout: SplitParser {
            onRead: data => {
                const col = data.trim();
                if (col.startsWith("#") && col.length === 7) {
                    root.mediaArtColor = col;
                }
            }
        }
    }

    function extractAlbumArtColor(artUrl) {
        if (!artUrl || artUrl.length === 0) {
            root.mediaArtColor = "#F4F4F6";
            return;
        }
        root.pendingArtUrl = String(artUrl);
        albumColorProc.running = false;
        albumColorProc.running = true;
    }

    // Track-Change "Now Playing" In-Between Dynamic Island Announcement State
    property bool mediaToastOpen: false
    property real mediaToastWidth: 0
    property real mediaToastHeight: 0
    readonly property real targetMediaToastWidth: 372
    readonly property real targetMediaToastHeight: 82
    readonly property real targetVolumeIslandWidth: 340
    readonly property real targetVolumeIslandHeight: 52
    readonly property real targetKbIslandWidth: Math.max(360, Math.min(460, activeKeyboardLayout.length * 8.4 + 230))
    readonly property real targetKbIslandHeight: 68
    readonly property real targetPowerIslandWidth: 440
    readonly property real targetPowerIslandHeight: 104

    ParallelAnimation {
        id: mediaToastOpenAnim
        alwaysRunToEnd: false

        NumberAnimation {
            target: root
            property: "mediaToastHeight"
            to: root.targetMediaToastHeight
            duration: root.animDur(360, 265)
            easing.type: root.animPrimaryEase
        }

        NumberAnimation {
            target: root
            property: "mediaToastWidth"
            to: root.targetMediaToastWidth
            duration: root.animDur(360, 265)
            easing.type: root.animPrimaryEase
        }
    }

    ParallelAnimation {
        id: mediaToastCloseAnim
        alwaysRunToEnd: false

        NumberAnimation {
            id: mediaToastCloseHeightAnim
            target: root
            property: "mediaToastHeight"
            to: 0
            duration: root.animDur(340, 240)
            easing.type: root.animPrimaryEase
        }
        NumberAnimation {
            id: mediaToastCloseWidthAnim
            target: root
            property: "mediaToastWidth"
            to: 0
            duration: root.animDur(340, 240)
            easing.type: root.animPrimaryEase
        }
    }

    Timer {
        id: mediaToastHideTimer
        interval: 3200
        repeat: false
        onTriggered: {
            root.mediaToastOpen = false;
        }
    }

    Timer {
        id: mediaToastHoverCloseTimer
        interval: 360
        repeat: false
        onTriggered: {
            root.mediaToastOpen = false;
        }
    }

    onMediaToastOpenChanged: {
        if (mediaToastOpen) {
            mediaToastCloseAnim.stop();
            mediaToastOpenAnim.restart();
        } else {
            mediaToastHideTimer.stop();
            mediaToastHoverCloseTimer.stop();
            mediaToastOpenAnim.stop();
            mediaToastCloseHeightAnim.from = mediaToastHeight;
            mediaToastCloseWidthAnim.from = mediaToastWidth;
            mediaToastCloseAnim.restart();
        }
    }

    function triggerMediaToast() {
        if (!root.announceMediaChanges) return;
        if (root.controlCenterOpen || root.notifOpen || root.powerOsdOpen || root.volumeOsdOpen || root.kbOsdOpen) return;
        mediaToastHoverCloseTimer.stop();
        root.mediaToastOpen = true;
        mediaToastHideTimer.restart();
    }

    function showMediaToastOnHover() {
        if (root.controlCenterOpen || root.notifOpen || root.powerOsdOpen || root.volumeOsdOpen || root.kbOsdOpen) return;
        mediaToastHoverCloseTimer.stop();
        root.mediaToastOpen = true;
        mediaToastHideTimer.restart();
    }

    function pauseMediaToastTimer() {
        mediaToastHideTimer.stop();
        mediaToastHoverCloseTimer.stop();
    }

    function resumeMediaToastTimer() {
        if (root.mediaToastOpen) {
            mediaToastHoverCloseTimer.restart();
        }
    }

    // 1. Left Island (Arch + Workspaces + Scratchpads -> morphs in-place into System Menu with universal Dynamic Island curves)
    readonly property string leftIslandMode: sysMenuOpen ? "sysMenu" : "collapsed"
    readonly property real targetLeftIslandWidth: sysMenuOpen ? Math.max(Theme.sysMenuWidth, leftIslandBaseWidth + 16) : leftIslandBaseWidth
    readonly property real targetLeftIslandHeight: sysMenuOpen ? (Theme.barHeight + Theme.sysMenuHeight) : Theme.barHeight

    property real leftIslandWidth: 230
    property real leftIslandHeight: Theme.barHeight
    property real smoothLeftIslandHeight: targetLeftIslandHeight
    property real rawLeftIslandRadius: sysMenuOpen ? Theme.panelRadius : Theme.barRadius

    Behavior on smoothLeftIslandHeight { NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase } }
    Behavior on rawLeftIslandRadius { NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase } }

    readonly property real leftIslandDeformScaleY: Math.max(0.86, Math.min(1.12, leftIslandHeight / Math.max(1, smoothLeftIslandHeight)))
    readonly property real leftIslandRadius: Math.min(rawLeftIslandRadius, leftIslandHeight / 2)

    property real leftW1: 230
    property int leftW1Dur: 220
    property real leftW2: 230
    property int leftW2Dur: 0
    property real leftH1: Theme.barHeight
    property int leftH1Dur: 220
    property real leftH2: Theme.barHeight
    property int leftH2Dur: 0

    property bool leftMorphRestarting: false

    ParallelAnimation {
        id: leftIslandMorphAnim
        alwaysRunToEnd: false
        onRunningChanged: {
            if (!running && !root.leftMorphRestarting && (Math.abs(root.leftIslandWidth - root.targetLeftIslandWidth) > 0.5 || Math.abs(root.leftIslandHeight - root.targetLeftIslandHeight) > 0.5)) {
                root.triggerLeftIslandMorph();
            }
        }

        SequentialAnimation {
            NumberAnimation { id: leftW1Anim; target: root; property: "leftIslandWidth"; to: root.leftW1; duration: root.leftW1Dur; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "leftIslandWidth"; to: root.leftW2; duration: root.leftW2Dur; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { id: leftH1Anim; target: root; property: "leftIslandHeight"; to: root.leftH1; duration: root.leftH1Dur; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "leftIslandHeight"; to: root.leftH2; duration: root.leftH2Dur; easing.type: Easing.InOutSine }
        }
    }

    function triggerLeftIslandMorph() {
        const curW = root.leftIslandWidth;
        const curH = root.leftIslandHeight;
        const dstW = root.targetLeftIslandWidth;
        const dstH = root.targetLeftIslandHeight;

        if (!leftIslandMorphAnim.running && Math.abs(dstW - curW) < 0.5 && Math.abs(dstH - curH) < 0.5) {
            return;
        }
        if (leftIslandMorphAnim.running && Math.abs(root.leftW2 - dstW) < 0.5 && Math.abs(root.leftH2 - dstH) < 0.5) {
            return;
        }

        root.leftMorphRestarting = true;
        leftIslandMorphAnim.stop();
        root.leftMorphRestarting = false;

        if (root.leftIslandMode === "collapsed" && curH <= Theme.barHeight + 2 && dstH <= Theme.barHeight + 2) {
            leftW1Anim.easing.type = root.animPrimaryEase;
            leftH1Anim.easing.type = root.animPrimaryEase;
            const dur = root.animDur(320, 220);
            root.leftW1 = dstW; root.leftW1Dur = dur;
            root.leftW2 = dstW; root.leftW2Dur = 0;
            root.leftH1 = dstH; root.leftH1Dur = dur;
            root.leftH2 = dstH; root.leftH2Dur = 0;
        } else if (root.leftIslandMode === "collapsed") {
            leftW1Anim.easing.type = root.animPrimaryEase;
            leftH1Anim.easing.type = root.animPrimaryEase;
            const dur = root.animDur(360, 220);
            root.leftW1 = dstW; root.leftW1Dur = dur;
            root.leftW2 = dstW; root.leftW2Dur = 0;
            root.leftH1 = dstH; root.leftH1Dur = dur;
            root.leftH2 = dstH; root.leftH2Dur = 0;
        } else if (curH > Theme.barHeight + 6) {
            leftW1Anim.easing.type = root.animPrimaryEase;
            leftH1Anim.easing.type = root.animPrimaryEase;
            const dur = root.animDur(320, 220);
            root.leftW1 = dstW; root.leftW1Dur = dur;
            root.leftW2 = dstW; root.leftW2Dur = 0;
            root.leftH1 = dstH; root.leftH1Dur = dur;
            root.leftH2 = dstH; root.leftH2Dur = 0;
        } else {
            leftW1Anim.easing.type = root.animPrimaryEase;
            leftH1Anim.easing.type = root.animPrimaryEase;
            const wMult = root.isSnappyAnimations ? 1.018 : 1.014;
            const hMult = root.isSnappyAnimations ? 1.022 : 1.016;
            const d1 = root.animDur(360, 265);
            const d2 = root.animDur(210, 170);
            root.leftW1 = dstW * wMult; root.leftW1Dur = d1;
            root.leftW2 = dstW;         root.leftW2Dur = d2;
            root.leftH1 = dstH * hMult; root.leftH1Dur = d1;
            root.leftH2 = dstH;         root.leftH2Dur = d2;
        }

        leftIslandMorphAnim.restart();
    }

    onTargetLeftIslandWidthChanged: triggerLeftIslandMorph()
    onTargetLeftIslandHeightChanged: triggerLeftIslandMorph()

    // 2. Center Dynamic Island (Unified Morph State: Collapsed <-> Media Toast <-> Volume <-> Power <-> Notif <-> Control Center)
    readonly property string centerIslandMode: {
        if (lockVisualOpen) return "lock";
        if (powerOsdOpen) return "power";
        if (launcherOpen) return "launcher";
        if (clipboardOpen) return "clipboard";
        if (settingsOpen) return "settings";
        if (cheatSheetOpen) return "cheatSheet";
        if (controlCenterOpen) return ccActiveTab === 1 ? "ccMedia" : "ccQuick";
        if (notifOpen && activeNotifsModel.count > 0) return "notif";
        if (volumeOsdOpen) return "volume";
        if (kbOsdOpen) return "kbLayout";
        if (mediaToastOpen) return "mediaToast";
        return "collapsed";
    }

    readonly property bool isFloatingModalMode: centerIslandMode === "launcher"
        || centerIslandMode === "clipboard"
        || centerIslandMode === "settings"
        || centerIslandMode === "cheatSheet"

    property real mainScreenX: 0
    property real mainScreenY: 0
    property real mainScreenWidth: 1920
    property real mainScreenHeight: 1080
    property int desktopLayoutRev: 0
    property string activeMonitorName: Theme.mainMonitorName

    // Per-monitor geometry & independent bar widths so every monitor runs and morphs separately
    property var monitorGeometries: ({})
    function setMonitorGeometry(monName, x, y, w, h) {
        if (!monName || w <= 0 || h <= 0) return;
        const cur = monitorGeometries[monName];
        if (!cur || cur.x !== x || cur.y !== y || cur.w !== w || cur.h !== h) {
            const next = Object.assign({}, monitorGeometries);
            next[monName] = { x: x, y: y, w: w, h: h };
            monitorGeometries = next;
        }
        if (monName === root.activeMonitorName) {
            root.mainScreenX = x;
            root.mainScreenY = y;
            root.mainScreenWidth = w;
            root.mainScreenHeight = h;
        }
    }

    property var secondaryBarWidths: ({})
    function setSecondaryBarWidths(monName, lW, cW, rW, archX) {
        if (!monName) return;
        const cur = secondaryBarWidths[monName];
        const ax = (archX !== undefined) ? archX : (cur ? cur.archX : 14);
        if (cur && Math.abs(cur.left - lW) < 0.5 && Math.abs(cur.center - cW) < 0.5
            && Math.abs(cur.right - rW) < 0.5 && Math.abs(cur.archX - ax) < 0.5) return;
        const next = Object.assign({}, secondaryBarWidths);
        next[monName] = { left: lW, center: cW, right: rW, archX: ax };
        secondaryBarWidths = next;
        if (monName === root.activeMonitorName) {
            root.leftIslandBaseWidth = lW;
            root.centerIslandBaseWidth = cW;
            root.rightIslandBaseWidth = rW;
            if (!root.sysMenuOpen && root.leftIslandHeight <= Theme.barHeight + 0.5) {
                root.archLogoBarX = ax;
            }
        }
    }
    function getSecondaryBarWidth(monName, kind, fallbackVal) {
        const entry = monName ? secondaryBarWidths[monName] : null;
        return (entry && entry[kind] !== undefined) ? entry[kind] : fallbackVal;
    }

    function hasAnyPanelOpen() {
        return root.sysMenuOpen || root.weatherOpen || root.weatherDebugOpen || root.notifCenterOpen
            || root.trayMenuOpen || root.controlCenterOpen || root.launcherOpen || root.clipboardOpen
            || root.settingsOpen || root.cheatSheetOpen || root.powerOsdOpen;
    }

    function activateMonitor(screenOrName) {
        const name = (typeof screenOrName === "string")
            ? screenOrName
            : ((screenOrName && screenOrName.name) ? String(screenOrName.name) : "");
        if (!name || name === root.activeMonitorName) return;

        // Close any open panel on the old monitor before handing ownership to the clicked/focused display
        root.sysMenuOpen = false;
        root.weatherOpen = false;
        root.weatherDebugOpen = false;
        root.notifCenterOpen = false;
        root.trayMenuOpen = false;
        root.controlCenterOpen = false;
        root.launcherOpen = false;
        root.clipboardOpen = false;
        root.settingsOpen = false;
        root.cheatSheetOpen = false;
        root.powerOsdOpen = false;
        root.mediaToastOpen = false;

        root.activeMonitorName = name;
        const geom = root.monitorGeometries[name];
        if (geom) {
            root.mainScreenX = geom.x;
            root.mainScreenY = geom.y;
            root.mainScreenWidth = geom.w;
            root.mainScreenHeight = geom.h;
        }
        const bw = root.secondaryBarWidths[name];
        if (bw) {
            root.leftIslandBaseWidth = bw.left;
            root.centerIslandBaseWidth = bw.center;
            root.rightIslandBaseWidth = bw.right;
            root.archLogoBarX = bw.archX;
            root.leftMorphRestarting = true;
        leftIslandMorphAnim.stop();
        root.leftMorphRestarting = false;
            root.islandMorphRestarting = true;
        islandMorphAnim.stop();
        root.islandMorphRestarting = false;
            root.rightMorphRestarting = true;
        rightIslandMorphAnim.stop();
        root.rightMorphRestarting = false;
            root.leftIslandWidth = bw.left;
            root.leftIslandHeight = Theme.barHeight;
            root.centerIslandWidth = bw.center;
            root.centerIslandHeight = Theme.barHeight;
            root.centerIslandY = Theme.barTopGap;
            root.rightIslandWidth = bw.right;
            root.rightIslandHeight = Theme.barHeight;
        }
    }

    function activateFocusedMonitorIfIdle() {
        if (hasAnyPanelOpen()) return;
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
            activateMonitor(String(Hyprland.focusedMonitor.name));
        }
    }

    function setMainMonitor(name) {
        const trimmed = String(name || "").trim();
        if (trimmed.length === 0) return;
        Theme.mainMonitorName = trimmed;
        root.activeMonitorName = trimmed;
        root.scheduleSaveState();
    }

    function isMainScreen(screenObj) {
        if (!screenObj) return true;
        if (screenObj.name === Theme.mainMonitorName) return true;
        const screens = Quickshell.screens;
        if (!screens || screens.length <= 1) return true;
        for (let i = 0; i < screens.length; ++i) {
            if (screens[i] && screens[i].name === Theme.mainMonitorName) {
                return false;
            }
        }
        return screens[0] === screenObj;
    }

    function findHyprMonitorForScreen(screenObj) {
        const targetName = (screenObj && screenObj.name) ? String(screenObj.name) : Theme.mainMonitorName;
        if (Hyprland.monitors && Hyprland.monitors.values) {
            const mons = Hyprland.monitors.values;
            for (let m = 0; m < mons.length; ++m) {
                if (mons[m] && String(mons[m].name) === targetName) {
                    return mons[m];
                }
            }
            if (!screenObj && mons.length > 0) return mons[0];
        }
        return Hyprland.focusedMonitor;
    }

    function activeWorkspaceIdForScreen(screenObj) {
        const _rev = root.desktopLayoutRev;
        const mon = findHyprMonitorForScreen(screenObj);
        if (mon && mon.activeWorkspace && mon.activeWorkspace.id !== undefined && Number(mon.activeWorkspace.id) > 0) {
            return Number(mon.activeWorkspace.id);
        }
        return (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ? Number(Hyprland.focusedWorkspace.id) : 1;
    }

    function topWindowForScreen(screenObj) {
        const _rev = root.desktopLayoutRev;
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) return null;
        const mon = findHyprMonitorForScreen(screenObj);
        if (!mon) return Hyprland.activeToplevel;
        const monId = (mon.id !== undefined) ? Number(mon.id) : -1;
        const wsId = (mon.activeWorkspace && mon.activeWorkspace.id !== undefined) ? Number(mon.activeWorkspace.id) : -1;
        let specialName = "";
        if (mon.lastIpcObject && mon.lastIpcObject.specialWorkspace && mon.lastIpcObject.specialWorkspace.name) {
            specialName = String(mon.lastIpcObject.specialWorkspace.name);
        }

        let bestTop = null;
        let bestHist = 999999;
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; ++i) {
            const top = vals[i];
            if (!top || !top.lastIpcObject) continue;
            const ipc = top.lastIpcObject;
            if (ipc.hidden) continue;
            if (monId >= 0 && ipc.monitor !== undefined && Number(ipc.monitor) !== monId) continue;
            const wObj = ipc.workspace;
            const wId = (wObj && wObj.id !== undefined) ? Number(wObj.id) : -999;
            const wName = (wObj && wObj.name !== undefined) ? String(wObj.name) : "";
            const isSpecialMatch = (specialName.length > 0 && wName === specialName);
            const isWsMatch = (wsId > 0 && wId === wsId);
            if (!ipc.pinned && !isSpecialMatch && !isWsMatch) continue;
            const hist = ipc.focusHistoryID !== undefined ? Number(ipc.focusHistoryID) : 500;
            if (hist < bestHist) {
                bestHist = hist;
                bestTop = top;
            }
        }
        return bestTop;
    }

    function syncKeyedListModel(listModel, newKeys) {
        const keepSet = {};
        for (let i = 0; i < newKeys.length; ++i) keepSet[newKeys[i]] = true;

        for (let i = listModel.count - 1; i >= 0; --i) {
            const k = listModel.get(i).itemKey;
            if (!keepSet[k]) listModel.remove(i, 1);
        }

        for (let targetIdx = 0; targetIdx < newKeys.length; ++targetIdx) {
            const key = newKeys[targetIdx];
            if (targetIdx < listModel.count && listModel.get(targetIdx).itemKey === key) {
                continue;
            }
            let foundIdx = -1;
            for (let j = targetIdx + 1; j < listModel.count; ++j) {
                if (listModel.get(j).itemKey === key) {
                    foundIdx = j;
                    break;
                }
            }
            if (foundIdx >= 0) {
                listModel.move(foundIdx, targetIdx, 1);
            } else {
                listModel.insert(targetIdx, { itemKey: key });
            }
        }
    }

    function desktopWindowsForScreen(screenObj) {
        const _rev = root.desktopLayoutRev;
        const _fw = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        const _at = Hyprland.activeToplevel;
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) return [];
        const mon = findHyprMonitorForScreen(screenObj);
        const fMon = Hyprland.focusedMonitor;
        const monId = (mon && mon.id !== undefined) ? Number(mon.id) : -1;
        const isFocusedMon = mon && fMon && Number(mon.id) === Number(fMon.id);
        const monX = screenObj ? Number(screenObj.x || 0) : ((mon && mon.x !== undefined) ? Number(mon.x) : root.mainScreenX);
        const monY = screenObj ? Number(screenObj.y || 0) : ((mon && mon.y !== undefined) ? Number(mon.y) : root.mainScreenY);
        const wsId = (isFocusedMon && _fw > 0)
            ? Number(_fw)
            : ((mon && mon.activeWorkspace && mon.activeWorkspace.id !== undefined) ? Number(mon.activeWorkspace.id) : Number(_fw));
        let specialName = "";
        if (mon && mon.lastIpcObject && mon.lastIpcObject.specialWorkspace && mon.lastIpcObject.specialWorkspace.name) {
            specialName = String(mon.lastIpcObject.specialWorkspace.name);
        }

        const list = [];
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; ++i) {
            const top = vals[i];
            if (!top || !top.wayland || !top.lastIpcObject) continue;
            const ipc = top.lastIpcObject;
            if (ipc.hidden) continue;
            if (monId >= 0 && ipc.monitor !== undefined && Number(ipc.monitor) !== monId) continue;

            const wObj = ipc.workspace;
            const wId = (wObj && wObj.id !== undefined) ? Number(wObj.id) : -999;
            const wName = (wObj && wObj.name !== undefined) ? String(wObj.name) : "";
            const isPinned = Boolean(ipc.pinned);
            const isSpecialMatch = (specialName.length > 0 && wName === specialName);
            const isWsMatch = (wsId > 0 && wId === wsId);
            if (!isPinned && !isSpecialMatch && !isWsMatch) continue;

            const at = ipc.at;
            const sz = ipc.size;
            if (!at || !sz || sz.length < 2 || Number(sz[0]) <= 0 || Number(sz[1]) <= 0) continue;

            const fhid = ipc.focusHistoryID !== undefined ? Number(ipc.focusHistoryID) : 50;
            const isFloating = Boolean(ipc.floating);
            const winZ = (isSpecialMatch ? 2000 : (isPinned ? 1500 : (isFloating ? 1000 : 0))) + (100 - Math.min(99, fhid));
            const winKey = ipc.address ? String(ipc.address) : String(top.wayland);

            list.push({
                winKey: winKey,
                wayland: top.wayland,
                winX: Number(at[0]) - monX,
                winY: Number(at[1]) - monY,
                winW: Number(sz[0]),
                winH: Number(sz[1]),
                winZ: winZ
            });
        }
        list.sort((a, b) => a.winZ - b.winZ);
        return list;
    }

    // Shared real-time window list on main monitor for Liquid Glass ScreencopyView capture
    readonly property var mainDesktopWindows: desktopWindowsForScreen(null)

    property int desktopRefreshRemaining: 0
    function scheduleDesktopRefresh(ticks) {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        root.desktopLayoutRev++;
        root.desktopRefreshRemaining = Math.max(root.desktopRefreshRemaining, ticks || 5);
        desktopRefreshTimer.restart();
    }

    Timer {
        id: desktopRefreshTimer
        interval: 110
        repeat: true
        Component.onCompleted: root.scheduleDesktopRefresh(6)
        onTriggered: {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
            root.desktopLayoutRev++;
            if (root.desktopRefreshRemaining > 1) {
                root.desktopRefreshRemaining--;
            } else {
                root.desktopRefreshRemaining = 0;
                stop();
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.scheduleDesktopRefresh(5); }
        function onActiveToplevelChanged() { root.scheduleDesktopRefresh(4); }
        function onFocusedMonitorChanged() { root.scheduleDesktopRefresh(5); }
        function onRawEvent(event) {
            const n = event ? event.name : "";
            if (n === "activelayout") {
                const raw = event && event.data ? String(event.data) : "";
                const commaIdx = raw.indexOf(",");
                const layoutName = (commaIdx >= 0 ? raw.slice(commaIdx + 1) : raw).trim();
                if (layoutName.length > 0 && (layoutName !== root.activeKeyboardLayout || root.kbSwitchPending)) {
                    root.activeKeyboardLayout = layoutName;
                    root.kbSwitchPending = false;
                    root.kbSwitchSeq++;
                    root.triggerKeyboardOsd();
                }
            } else if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "resizewindow" || n === "activewindow" || n === "activewindowv2"
                || n === "workspace" || n === "workspacev2" || n === "focusedmon"
                || n === "activespecial" || n === "changefloatingmode" || n === "fullscreen" || n === "pin"
                || n === "monitoradded" || n === "monitorremoved") {
                root.scheduleDesktopRefresh(5);
            }
        }
    }

    onCenterIslandModeChanged: {
        if (centerIslandMode !== _curIslandMode) {
            _prevIslandMode = _curIslandMode;
            _curIslandMode = centerIslandMode;
        }
        if (centerIslandMode !== "collapsed") scheduleDesktopRefresh(2);
    }
    onLeftIslandModeChanged: if (leftIslandMode !== "collapsed") scheduleDesktopRefresh(2)

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            root.desktopLayoutRev++;
        }
    }

    Connections {
        target: Hyprland.monitors
        function onValuesChanged() {
            root.desktopLayoutRev++;
        }
    }

    function modalDestWidth(mode) {
        let baseW = 520;
        if (mode === "launcher" || mode === "clipboard") baseW = Theme.launcherCardWidth;
        else if (mode === "settings") baseW = 740;
        else if (mode === "cheatSheet") baseW = 920;
        return Math.min(baseW, Math.max(240, mainScreenWidth - 48));
    }

    function modalDestHeight(mode) {
        let baseH = 470;
        if (mode === "launcher") baseH = Theme.launcherMaxHeight;
        else if (mode === "clipboard") baseH = Theme.launcherCardHeight;
        else if (mode === "settings") baseH = 760;
        else if (mode === "cheatSheet") baseH = 760;
        return Math.min(baseH, Math.max(200, mainScreenHeight - Theme.barBottomY - 48));
    }

    function modalDestY(mode) {
        const h = modalDestHeight(mode);
        return Math.max(Theme.barBottomY + 18, Math.round((mainScreenHeight - h) / 2));
    }

    readonly property real targetCenterIslandWidth: {
        switch (centerIslandMode) {
            case "lock": return mainScreenWidth;
            case "power": return targetPowerIslandWidth;
            case "launcher":
            case "clipboard":
            case "settings":
            case "cheatSheet": return modalDestWidth(centerIslandMode);
            case "ccMedia":
            case "ccQuick": return Theme.ccMaxWidth;
            case "notif": return Theme.notifCardWidth;
            case "volume": return targetVolumeIslandWidth;
            case "kbLayout": return targetKbIslandWidth;
            case "mediaToast": return targetMediaToastWidth;
            default: return centerIslandBaseWidth;
        }
    }

    readonly property real targetCenterIslandHeight: {
        switch (centerIslandMode) {
            case "lock": return mainScreenHeight;
            case "power": return targetPowerIslandHeight;
            case "launcher":
            case "clipboard":
            case "settings":
            case "cheatSheet": return modalDestHeight(centerIslandMode);
            case "ccMedia":
            case "ccQuick": return targetCcHeight;
            case "notif": return targetNotifHeight + 6;
            case "volume": return targetVolumeIslandHeight;
            case "kbLayout": return targetKbIslandHeight;
            case "mediaToast": return targetMediaToastHeight;
            default: return Theme.barHeight;
        }
    }

    readonly property real targetCenterIslandY: (centerIslandMode === "lock")
        ? 0
        : (isFloatingModalMode ? modalDestY(centerIslandMode) : Theme.barTopGap)

    readonly property real targetCenterIslandRadius: {
        switch (centerIslandMode) {
            case "lock": return 0;
            case "power":
            case "ccMedia":
            case "ccQuick": return 42;
            case "launcher":
            case "clipboard": return Theme.radiusLarge;
            case "settings":
            case "cheatSheet": return 22;
            case "mediaToast": return 41;
            case "notif": return 38;
            case "volume": return 26;
            case "kbLayout": return 34;
            default: return Theme.barRadius;
        }
    }

    property real centerIslandWidth: 210
    property real centerIslandHeight: Theme.barHeight
    property real centerIslandY: Theme.barTopGap
    property real smoothCenterIslandWidth: targetCenterIslandWidth
    property real smoothCenterIslandHeight: targetCenterIslandHeight
    property real rawCenterIslandRadius: Theme.barRadius
    readonly property real centerIslandRadius: Math.min(rawCenterIslandRadius, centerIslandHeight / 2)
    property bool centerIslandOverlayMorph: false
    property bool isModalMorphing: false
    property bool islandMorphRestarting: false
    property bool ccOverlayVisible: false
    property string _curIslandMode: "collapsed"
    property string _prevIslandMode: "collapsed"
    readonly property bool isCenterIslandMorphing: islandMorphAnim.running && centerIslandOverlayMorph
    readonly property bool isCcOrMediaMode: centerIslandMode === "ccQuick" || centerIslandMode === "ccMedia" || centerIslandMode === "mediaToast"
    readonly property bool isCcOrMediaMorph: isCenterIslandMorphing && (isCcOrMediaMode || _prevIslandMode === "ccQuick" || _prevIslandMode === "ccMedia" || _prevIslandMode === "mediaToast")

    Behavior on smoothCenterIslandWidth {
        NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase }
    }
    Behavior on smoothCenterIslandHeight {
        NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase }
    }
    Behavior on rawCenterIslandRadius {
        NumberAnimation { duration: root.animDur(380, 320); easing.type: root.animPrimaryEase }
    }

    // Live 2D Elastic Deformation Ratios (clamped so content stretches subtly on return without warping)
    readonly property real islandDeformScaleX: Math.max(0.86, Math.min(1.10, centerIslandWidth / Math.max(1, smoothCenterIslandWidth)))
    readonly property real islandDeformScaleY: Math.max(0.86, Math.min(1.12, centerIslandHeight / Math.max(1, smoothCenterIslandHeight)))

    // Dynamic 2D Squash-and-Stretch (Honor Magic Capsule) Spring Parameters
    property real islandW0: 210
    property int islandW0Dur: 0
    property real islandW1: 210
    property int islandW1Dur: 265
    property real islandW2: 210
    property int islandW2Dur: 185
    property real islandW3: 210
    property int islandW3Dur: 155

    property real islandH1: 38
    property int islandH1Dur: 260
    property real islandH2: 38
    property int islandH2Dur: 185
    property real islandH3: 38
    property int islandH3Dur: 160

    property real islandY1: Theme.barTopGap
    property int islandY1Dur: 0
    property real islandY2: Theme.barTopGap
    property int islandY2Dur: 0
    property real islandY3: Theme.barTopGap
    property int islandY3Dur: 0

    property int islandStage1Easing: Easing.OutCubic

    ParallelAnimation {
        id: islandMorphAnim
        alwaysRunToEnd: false
        onRunningChanged: {
            if (!running && !root.islandMorphRestarting) {
                root.centerIslandOverlayMorph = false;
                root.isModalMorphing = false;
                root._prevIslandMode = root.centerIslandMode;
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "centerIslandWidth"
                to: root.islandW0
                duration: root.islandW0Dur
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root
                property: "centerIslandWidth"
                to: root.islandW1
                duration: root.islandW1Dur
                easing.type: root.islandStage1Easing
            }
            NumberAnimation {
                target: root
                property: "centerIslandWidth"
                to: root.islandW2
                duration: root.islandW2Dur
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "centerIslandWidth"
                to: root.islandW3
                duration: root.islandW3Dur
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "centerIslandHeight"
                to: root.islandH1
                duration: root.islandH1Dur
                easing.type: root.islandStage1Easing
            }
            NumberAnimation {
                target: root
                property: "centerIslandHeight"
                to: root.islandH2
                duration: root.islandH2Dur
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "centerIslandHeight"
                to: root.islandH3
                duration: root.islandH3Dur
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "centerIslandY"
                to: root.islandY1
                duration: root.islandY1Dur
                easing.type: root.islandStage1Easing
            }
            NumberAnimation {
                target: root
                property: "centerIslandY"
                to: root.islandY2
                duration: root.islandY2Dur
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "centerIslandY"
                to: root.islandY3
                duration: root.islandY3Dur
                easing.type: Easing.InOutSine
            }
        }
    }

    function triggerCenterIslandMorph() {
        const curW = root.centerIslandWidth;
        const curH = root.centerIslandHeight;
        const curY = root.centerIslandY;
        const dstW = root.targetCenterIslandWidth;
        const dstH = root.targetCenterIslandHeight;
        const dstY = root.targetCenterIslandY;
        root.rawCenterIslandRadius = root.targetCenterIslandRadius;

        if (!islandMorphAnim.running && Math.abs(dstW - curW) < 0.5 && Math.abs(dstH - curH) < 0.5 && Math.abs(dstY - curY) < 0.5) {
            return;
        }
        if (islandMorphAnim.running && Math.abs(root.islandW3 - dstW) < 0.5 && Math.abs(root.islandH3 - dstH) < 0.5 && Math.abs(root.islandY3 - dstY) < 0.5) {
            return;
        }

        root.islandMorphRestarting = true;
        islandMorphAnim.stop();
        root.islandMorphRestarting = false;

        const isLockTransition = (root.centerIslandMode === "lock") || (curW >= mainScreenWidth - 36 && curH >= mainScreenHeight - 36);
        const isModalTransition = !isLockTransition && (root.isFloatingModalMode || curY > Theme.barTopGap + 1);
        root.isModalMorphing = isModalTransition;

        // 1. Simple, non-bouncing smooth morph for:
        //    - Collapsed capsule width changes (track title length or window title resize — no overlay handoff)
        //    - Small expands/collapses like the Volume Slider pill
        //    - Switching tabs (Quick <-> Media) or opening/closing submenus at constant width
        const isPureCollapsedResize = (!isLockTransition && root.centerIslandMode === "collapsed" && curH <= Theme.barHeight + 2 && dstH <= Theme.barHeight + 2 && !root.centerIslandOverlayMorph && !isModalTransition);
        root.centerIslandOverlayMorph = !isPureCollapsedResize && !isModalTransition && !isLockTransition;

        const isSmallVolumeMorph = !isLockTransition && !isModalTransition && (root.centerIslandMode === "volume"
            || (root.centerIslandMode === "collapsed" && curH <= root.targetVolumeIslandHeight + 6));
        const isTabOrSubmenuSwitch = !isLockTransition && !isModalTransition && (Math.abs(dstW - curW) < 4 && Math.abs(dstH - curH) > 12);

        if (isLockTransition) {
            if (root.centerIslandMode === "lock") {
                // Physical Dynamic Island expansion from bar capsule out to fill the screen
                root.islandStage1Easing = root.animPrimaryEase;
                root.islandW0 = curW;
                root.islandW0Dur = 0;
                root.islandW1 = dstW;
                root.islandW1Dur = root.animDur(560, 440);
                root.islandW2 = dstW;
                root.islandW2Dur = 0;
                root.islandW3 = dstW;
                root.islandW3Dur = 0;

                root.islandH1 = dstH;
                root.islandH1Dur = root.animDur(580, 460);
                root.islandH2 = dstH;
                root.islandH2Dur = 0;
                root.islandH3 = dstH;
                root.islandH3Dur = 0;

                root.islandY1 = dstY;
                root.islandY1Dur = root.animDur(520, 400);
                root.islandY2 = dstY;
                root.islandY2Dur = 0;
                root.islandY3 = dstY;
                root.islandY3Dur = 0;
            } else {
                // Re-minimize smoothly from full-screen lock back into the top Dynamic Island pill
                const closeWMult = root.isSnappyAnimations ? 0.945 : 0.962;
                const closeHMult = root.isSnappyAnimations ? 1.055 : 1.038;
                const d1 = root.animDur(480, 360);
                const d2 = root.animDur(210, 140);
                const d3 = root.animDur(170, 110);
                root.islandStage1Easing = Easing.InOutCubic;
                root.islandW0 = curW;
                root.islandW0Dur = 0;
                root.islandW1 = dstW * closeWMult;
                root.islandW1Dur = d1;
                root.islandW2 = dstW * 1.006;
                root.islandW2Dur = d2;
                root.islandW3 = dstW;
                root.islandW3Dur = d3;

                root.islandH1 = dstH * closeHMult;
                root.islandH1Dur = d1;
                root.islandH2 = dstH * 0.990;
                root.islandH2Dur = d2;
                root.islandH3 = dstH;
                root.islandH3Dur = d3;

                root.islandY1 = dstY;
                root.islandY1Dur = d1;
                root.islandY2 = dstY;
                root.islandY2Dur = 0;
                root.islandY3 = dstY;
                root.islandY3Dur = 0;
            }
        } else if (isModalTransition) {
            root.islandStage1Easing = root.isSnappyAnimations && dstY <= Theme.barTopGap + 1 ? Easing.InOutCubic : Easing.InOutCubic;
            root.islandW0 = curW;
            root.islandW0Dur = 0;

            if (dstY > Theme.barTopGap + 1) {
                const yOvershoot = root.isSnappyAnimations
                    ? Math.min(12, Math.max(4, (dstY - Theme.barTopGap) * 0.024))
                    : Math.min(8, Math.max(3, (dstY - Theme.barTopGap) * 0.016));
                const d1 = root.animDur(420, 320);
                const d2 = root.animDur(230, 175);
                const d3 = root.animDur(180, 135);
                root.islandW1 = dstW * (root.isSnappyAnimations ? 1.032 : 1.020);
                root.islandW1Dur = d1;
                root.islandW2 = dstW * (root.isSnappyAnimations ? 0.994 : 0.996);
                root.islandW2Dur = d2;
                root.islandW3 = dstW;
                root.islandW3Dur = d3;

                root.islandH1 = dstH * (root.isSnappyAnimations ? 1.036 : 1.024);
                root.islandH1Dur = d1;
                root.islandH2 = dstH * (root.isSnappyAnimations ? 0.993 : 0.995);
                root.islandH2Dur = d2;
                root.islandH3 = dstH;
                root.islandH3Dur = d3;

                root.islandY1 = dstY + yOvershoot;
                root.islandY1Dur = d1 + 10;
                root.islandY2 = dstY - (root.isSnappyAnimations ? 3 : 2);
                root.islandY2Dur = d2;
                root.islandY3 = dstY;
                root.islandY3Dur = d3;
            } else {
                const d1 = root.animDur(380, 290);
                const d2 = root.animDur(210, 155);
                const d3 = root.animDur(170, 120);
                root.islandW1 = dstW * (root.isSnappyAnimations ? 0.945 : 0.962);
                root.islandW1Dur = d1;
                root.islandW2 = dstW * 1.008;
                root.islandW2Dur = d2;
                root.islandW3 = dstW;
                root.islandW3Dur = d3;

                root.islandH1 = dstH * (root.isSnappyAnimations ? 1.055 : 1.038);
                root.islandH1Dur = d1;
                root.islandH2 = dstH * 0.985;
                root.islandH2Dur = d2;
                root.islandH3 = dstH;
                root.islandH3Dur = d3;

                root.islandY1 = dstY;
                root.islandY1Dur = d1;
                root.islandY2 = dstY;
                root.islandY2Dur = 0;
                root.islandY3 = dstY;
                root.islandY3Dur = 0;
            }
        } else if (isPureCollapsedResize || isSmallVolumeMorph || isTabOrSubmenuSwitch) {
            root.islandStage1Easing = root.animPrimaryEase;
            const morphDur = isPureCollapsedResize
                ? root.animDur(320, 240)
                : (isSmallVolumeMorph ? root.animDur(400, 340) : root.animDur(360, 280));
            root.islandW0 = curW;
            root.islandW0Dur = 0;
            root.islandW1 = dstW;
            root.islandW1Dur = morphDur;
            root.islandW2 = dstW;
            root.islandW2Dur = 0;
            root.islandW3 = dstW;
            root.islandW3Dur = 0;

            root.islandH1 = dstH;
            root.islandH1Dur = morphDur;
            root.islandH2 = dstH;
            root.islandH2Dur = 0;
            root.islandH3 = dstH;
            root.islandH3Dur = 0;

            root.islandY1 = dstY;
            root.islandY1Dur = curY !== dstY ? morphDur : 0;
            root.islandY2 = dstY;
            root.islandY2Dur = 0;
            root.islandY3 = dstY;
            root.islandY3Dur = 0;
        } else if (root.centerIslandMode === "collapsed") {
            root.islandStage1Easing = root.animPrimaryEase;
            const d1 = root.animDur(350, 240);
            const d2 = root.animDur(200, 165);
            const d3 = root.animDur(160, 135);
            root.islandW0 = curW;
            root.islandW0Dur = 0;
            root.islandW1 = dstW * (root.isSnappyAnimations ? 0.945 : 0.962);
            root.islandW1Dur = d1;
            root.islandW2 = dstW * (root.isSnappyAnimations ? 1.008 : 1.006);
            root.islandW2Dur = d2;
            root.islandW3 = dstW;
            root.islandW3Dur = d3;

            root.islandH1 = dstH * (root.isSnappyAnimations ? 1.055 : 1.038);
            root.islandH1Dur = d1;
            root.islandH2 = dstH * (root.isSnappyAnimations ? 0.985 : 0.990);
            root.islandH2Dur = d2;
            root.islandH3 = dstH;
            root.islandH3Dur = d3;

            root.islandY1 = dstY;
            root.islandY1Dur = 0;
            root.islandY2 = dstY;
            root.islandY2Dur = 0;
            root.islandY3 = dstY;
            root.islandY3Dur = 0;
        } else {
            root.islandStage1Easing = root.animPrimaryEase;
            const d1 = root.animDur(360, 265);
            const d2 = root.animDur(200, 175);
            const d3 = root.animDur(160, 145);
            root.islandW0 = curW;
            root.islandW0Dur = 0;
            root.islandW1 = dstW * (root.isSnappyAnimations ? 1.032 : 1.018);
            root.islandW1Dur = d1;
            root.islandW2 = dstW * (root.isSnappyAnimations ? 0.994 : 0.996);
            root.islandW2Dur = d2;
            root.islandW3 = dstW;
            root.islandW3Dur = d3;

            root.islandH1 = dstH * (root.isSnappyAnimations ? 1.038 : 1.022);
            root.islandH1Dur = d1;
            root.islandH2 = dstH * (root.isSnappyAnimations ? 0.993 : 0.995);
            root.islandH2Dur = d2;
            root.islandH3 = dstH;
            root.islandH3Dur = d3;

            root.islandY1 = dstY;
            root.islandY1Dur = 0;
            root.islandY2 = dstY;
            root.islandY2Dur = 0;
            root.islandY3 = dstY;
            root.islandY3Dur = 0;
        }

        islandMorphAnim.restart();
    }

    onTargetCenterIslandWidthChanged: triggerCenterIslandMorph()
    onTargetCenterIslandHeightChanged: triggerCenterIslandMorph()
    onTargetCenterIslandYChanged: triggerCenterIslandMorph()
    onTargetCenterIslandRadiusChanged: rawCenterIslandRadius = targetCenterIslandRadius

    // 3. Right Island (Tray + Weather + Battery + Clock + Bell -> morphs into Notification Center / Weather with universal Dynamic Island curves)
    readonly property string rightIslandMode: {
        if (notifCenterOpen) return "notifCenter";
        if (weatherOpen) return "weather";
        return "collapsed";
    }
    property string rightIslandOwner: "none"
    onRightIslandModeChanged: {
        if (rightIslandMode !== "collapsed") {
            rightIslandOwner = rightIslandMode;
            scheduleDesktopRefresh(2);
        }
    }

    readonly property real targetNotifCenterWidth: Math.max(Theme.notifCenterWidth, rightIslandBaseWidth + 16)
    readonly property real targetWeatherWidth: Math.max(Theme.weatherCardWidth, rightIslandBaseWidth + 16)

    readonly property real targetRightIslandWidth: {
        if (rightIslandMode === "notifCenter") return targetNotifCenterWidth;
        if (rightIslandMode === "weather") return targetWeatherWidth;
        return rightIslandBaseWidth;
    }

    readonly property real targetRightIslandHeight: {
        if (rightIslandMode === "notifCenter") return Theme.barHeight + targetNotifCenterHeight;
        if (rightIslandMode === "weather") return Theme.barHeight + Theme.weatherMaxHeight;
        return Theme.barHeight;
    }

    property real rightIslandWidth: 310
    property real rightIslandHeight: Theme.barHeight
    property real smoothRightIslandHeight: targetRightIslandHeight
    property real rawRightIslandRadius: (rightIslandMode !== "collapsed") ? Theme.panelRadius : Theme.barRadius

    onRightIslandHeightChanged: {
        if (rightIslandMode === "collapsed" && rightIslandHeight <= Theme.barHeight + 0.5) {
            rightIslandOwner = "none";
        }
    }

    Behavior on smoothRightIslandHeight { NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase } }
    Behavior on rawRightIslandRadius { NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase } }

    readonly property real rightIslandDeformScaleY: Math.max(0.86, Math.min(1.12, rightIslandHeight / Math.max(1, smoothRightIslandHeight)))
    readonly property real rightIslandRadius: Math.min(rawRightIslandRadius, rightIslandHeight / 2)

    property real rightW1: 310
    property int rightW1Dur: 220
    property real rightW2: 310
    property int rightW2Dur: 0
    property real rightH1: Theme.barHeight
    property int rightH1Dur: 220
    property real rightH2: Theme.barHeight
    property int rightH2Dur: 0

    property bool rightMorphRestarting: false

    ParallelAnimation {
        id: rightIslandMorphAnim
        alwaysRunToEnd: false
        onRunningChanged: {
            if (!running && !root.rightMorphRestarting && root.rightIslandMode === "collapsed") {
                root.rightIslandHeight = Theme.barHeight;
                root.rightIslandWidth = root.rightIslandBaseWidth;
                root.rightIslandOwner = "none";
            }
        }

        SequentialAnimation {
            NumberAnimation { id: rightW1Anim; target: root; property: "rightIslandWidth"; to: root.rightW1; duration: root.rightW1Dur; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "rightIslandWidth"; to: root.rightW2; duration: root.rightW2Dur; easing.type: Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { id: rightH1Anim; target: root; property: "rightIslandHeight"; to: root.rightH1; duration: root.rightH1Dur; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "rightIslandHeight"; to: root.rightH2; duration: root.rightH2Dur; easing.type: Easing.InOutSine }
        }
    }

    function triggerRightIslandMorph() {
        const curW = root.rightIslandWidth;
        const curH = root.rightIslandHeight;
        const dstW = root.targetRightIslandWidth;
        const dstH = root.targetRightIslandHeight;

        if (!rightIslandMorphAnim.running && Math.abs(dstW - curW) < 0.5 && Math.abs(dstH - curH) < 0.5) {
            return;
        }
        if (rightIslandMorphAnim.running && Math.abs(root.rightW2 - dstW) < 0.5 && Math.abs(root.rightH2 - dstH) < 0.5) {
            return;
        }

        root.rightMorphRestarting = true;
        rightIslandMorphAnim.stop();
        root.rightMorphRestarting = false;

        const isPureCollapsedResize = (root.rightIslandMode === "collapsed" && curH <= Theme.barHeight + 2 && dstH <= Theme.barHeight + 2);
        const isAlreadyOpenSwitchOrAdapt = (root.rightIslandMode !== "collapsed" && curH > Theme.barHeight + 6);

        if (isPureCollapsedResize || isAlreadyOpenSwitchOrAdapt) {
            rightW1Anim.easing.type = root.animPrimaryEase;
            rightH1Anim.easing.type = root.animPrimaryEase;
            const dur = isPureCollapsedResize ? root.animDur(320, 220) : root.animDur(350, 250);
            root.rightW1 = dstW; root.rightW1Dur = dur;
            root.rightW2 = dstW; root.rightW2Dur = 0;
            root.rightH1 = dstH; root.rightH1Dur = dur;
            root.rightH2 = dstH; root.rightH2Dur = 0;
        } else if (root.rightIslandMode === "collapsed") {
            rightW1Anim.easing.type = root.animPrimaryEase;
            rightH1Anim.easing.type = root.animPrimaryEase;
            const dur = root.animDur(360, 220);
            root.rightW1 = dstW; root.rightW1Dur = dur;
            root.rightW2 = dstW; root.rightW2Dur = 0;
            root.rightH1 = dstH; root.rightH1Dur = dur;
            root.rightH2 = dstH; root.rightH2Dur = 0;
        } else {
            rightW1Anim.easing.type = root.animPrimaryEase;
            rightH1Anim.easing.type = root.animPrimaryEase;
            const wMult = root.isSnappyAnimations ? 1.018 : 1.014;
            const hMult = root.isSnappyAnimations ? 1.022 : 1.016;
            const d1 = root.animDur(360, 265);
            const d2 = root.animDur(210, 170);
            root.rightW1 = dstW * wMult; root.rightW1Dur = d1;
            root.rightW2 = dstW;         root.rightW2Dur = d2;
            root.rightH1 = dstH * hMult; root.rightH1Dur = d1;
            root.rightH2 = dstH;         root.rightH2Dur = d2;
        }

        rightIslandMorphAnim.restart();
    }

    onTargetRightIslandWidthChanged: triggerRightIslandMorph()
    onTargetRightIslandHeightChanged: triggerRightIslandMorph()

    // Persistent Notification History Model for Control Center Tabs (Quick & Alerts)
    ListModel {
        id: notifHistoryModel
    }
    readonly property alias notifHistoryModel: notifHistoryModel

    // Active Stacked Notification Popups (Max 2 cards)
    ListModel {
        id: activeNotifsModel
    }
    readonly property alias activeNotifsModel: activeNotifsModel

    readonly property real targetNotifHeight: activeNotifsModel.count > 1 ? (Theme.notifCardHeight * 2) : Theme.notifCardHeight

    NumberAnimation {
        id: notifHeightExpandAnim
        target: root
        property: "notifHeight"
        to: root.targetNotifHeight
        duration: root.animDur(340, 250)
        easing.type: root.animPrimaryEase
    }

    function dismissFromHistory(idx) {
        if (idx >= 0 && idx < notifHistoryModel.count) {
            notifHistoryModel.remove(idx);
        }
    }

    property bool isClearingHistory: false
    property double notifCenterOpenedAt: 0

    Timer {
        id: clearFinishTimer
        repeat: false
        interval: 320
        onTriggered: {
            notifHistoryModel.clear();
            root.isClearingHistory = false;
        }
    }

    function clearAllHistory() {
        if (root.isClearingHistory) return;
        const total = notifHistoryModel.count;
        if (total <= 0) return;
        if (!root.notifCenterOpen) {
            notifHistoryModel.clear();
            return;
        }
        root.isClearingHistory = true;
        // Cards float and fade out smoothly one by one with a 65ms stagger inside the panel
        const visibleCount = Math.min(total, 7);
        clearFinishTimer.interval = 280 + Math.max(0, visibleCount - 1) * 65;
        clearFinishTimer.restart();
    }

    function dismissActiveNotif(idx) {
        if (idx >= 0 && idx < activeNotifsModel.count) {
            activeNotifsModel.remove(idx);
        }
        if (activeNotifsModel.count === 0) {
            root.notifOpen = false;
        } else {
            notifOpenAnim.stop();
            notifHeightExpandAnim.to = root.targetNotifHeight;
            notifHeightExpandAnim.restart();
        }
    }

    function focusAppItem(item) {
        if (!item) return;
        try {
            if (item.rawNotif && item.rawNotif.actions) {
                let invoked = false;
                for (let i = 0; i < item.rawNotif.actions.length; i++) {
                    const act = item.rawNotif.actions[i];
                    if (act && (act.identifier === "default" || act.identifier === "" || act.text === "default")) {
                        act.invoke();
                        invoked = true;
                        break;
                    }
                }
                if (!invoked && item.rawNotif.actions.length > 0) {
                    item.rawNotif.actions[0].invoke();
                }
            }
        } catch (e) {
            console.warn("Could not invoke notification action:", e);
        }
    }

    function activateNotification(idx) {
        if (idx < 0 || idx >= activeNotifsModel.count) return;
        const item = activeNotifsModel.get(idx);
        focusAppItem(item);
        dismissActiveNotif(idx);
    }

    function activateHistoryNotification(idx) {
        if (idx < 0 || idx >= notifHistoryModel.count) return;
        const item = notifHistoryModel.get(idx);
        focusAppItem(item);
        dismissFromHistory(idx);
        root.controlCenterOpen = false;
    }

    // Software Display Brightness State
    property real brightness: 1.0

    Timer {
        id: brightnessDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            Quickshell.execDetached([root.script("brightness.sh"), root.brightness.toFixed(2)]);
            root.scheduleSaveState();
        }
    }

    function setBrightness(val, immediate) {
        const clamped = Math.max(0.15, Math.min(1.0, val));
        root.brightness = clamped;
        if (immediate) {
            brightnessDebounceTimer.stop();
            Quickshell.execDetached([root.script("brightness.sh"), root.brightness.toFixed(2)]);
            root.scheduleSaveState();
        } else {
            brightnessDebounceTimer.restart();
        }
    }

    // High-Damping Minimalist Spring Morph Animations (Balanced Apple-style Micro-Cushion)
    ParallelAnimation {
        id: ccOpenAnim
        alwaysRunToEnd: false

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "ccHeight"
                to: root.targetCcHeight * (root.isSnappyAnimations ? 1.022 : 1.018)
                duration: root.animDur(360, 265)
                easing.type: root.animPrimaryEase
            }
            NumberAnimation {
                target: root
                property: "ccHeight"
                to: root.targetCcHeight
                duration: root.animDur(200, 170)
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "ccWidth"
                to: Theme.ccMaxWidth * (root.isSnappyAnimations ? 1.018 : 1.015)
                duration: root.animDur(360, 265)
                easing.type: root.animPrimaryEase
            }
            NumberAnimation {
                target: root
                property: "ccWidth"
                to: Theme.ccMaxWidth
                duration: root.animDur(200, 170)
                easing.type: Easing.InOutSine
            }
        }
    }

    ParallelAnimation {
        id: ccCloseAnim
        NumberAnimation {
            id: ccCloseHeightAnim
            target: root
            property: "ccHeight"
            to: 0
            duration: root.animDur(350, 240)
            easing.type: root.animPrimaryEase
        }
        NumberAnimation {
            id: ccCloseWidthAnim
            target: root
            property: "ccWidth"
            to: 0
            duration: root.animDur(350, 240)
            easing.type: root.animPrimaryEase
        }
    }

    ParallelAnimation {
        id: volumeOpenAnim
        alwaysRunToEnd: false

        NumberAnimation {
            target: root
            property: "volumeOsdWidth"
            to: root.targetVolumeIslandWidth
            duration: root.animDur(400, 340)
            easing.type: root.animPrimaryEase
        }

        NumberAnimation {
            target: root
            property: "volumeHeight"
            to: root.targetVolumeIslandHeight
            duration: root.animDur(400, 340)
            easing.type: root.animPrimaryEase
        }
    }

    ParallelAnimation {
        id: volumeCloseAnim
        NumberAnimation {
            id: volumeCloseWidthAnim
            target: root
            property: "volumeOsdWidth"
            to: 0
            duration: root.animDur(360, 280)
            easing.type: root.animPrimaryEase
        }
        NumberAnimation {
            target: root
            property: "volumeHeight"
            to: Theme.barHeight
            duration: root.animDur(360, 280)
            easing.type: root.animPrimaryEase
        }
    }

    // Center Dynamic Island Power Menu Morph
    ParallelAnimation {
        id: powerOsdOpenAnim
        alwaysRunToEnd: false

        NumberAnimation {
            target: root
            property: "powerOsdWidth"
            to: root.targetPowerIslandWidth
            duration: root.animDur(360, 265)
            easing.type: root.animPrimaryEase
        }

        NumberAnimation {
            target: root
            property: "powerOsdHeight"
            to: root.targetPowerIslandHeight
            duration: root.animDur(360, 265)
            easing.type: root.animPrimaryEase
        }
    }

    ParallelAnimation {
        id: powerOsdCloseAnim
        NumberAnimation {
            id: powerOsdCloseWidthAnim
            target: root
            property: "powerOsdWidth"
            to: 0
            duration: root.animDur(350, 240)
            easing.type: root.animPrimaryEase
        }
    }

    // Top-Right Corner Notification Popup Minimalist Spring Morph
    ParallelAnimation {
        id: notifOpenAnim
        alwaysRunToEnd: false

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "notifHeight"
                to: root.targetNotifHeight * (root.isSnappyAnimations ? 1.022 : 1.018)
                duration: root.animDur(360, 265)
                easing.type: root.animPrimaryEase
            }
            NumberAnimation {
                target: root
                property: "notifHeight"
                to: root.targetNotifHeight
                duration: root.animDur(200, 170)
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "notifWidth"
                to: Theme.notifCardWidth * (root.isSnappyAnimations ? 1.018 : 1.016)
                duration: root.animDur(360, 265)
                easing.type: root.animPrimaryEase
            }
            NumberAnimation {
                target: root
                property: "notifWidth"
                to: Theme.notifCardWidth
                duration: root.animDur(200, 170)
                easing.type: Easing.InOutSine
            }
        }
    }

    ParallelAnimation {
        id: notifCloseAnim
        alwaysRunToEnd: false

        NumberAnimation {
            id: notifCloseHeightAnim
            target: root
            property: "notifHeight"
            to: 0
            duration: root.animDur(350, 220)
            easing.type: root.animPrimaryEase
        }
        NumberAnimation {
            id: notifCloseWidthAnim
            target: root
            property: "notifWidth"
            to: 0
            duration: root.animDur(350, 220)
            easing.type: root.animPrimaryEase
        }
    }

    // Compact System Tray Menu Island (Dynamic Island Elastic Morph at clicked tray icon's needed width)
    readonly property real trayCollapsedWidth: Math.min(trayMenuTargetWidth, 44)
    readonly property real targetTrayIslandWidth: trayMenuOpen ? trayMenuTargetWidth : trayCollapsedWidth
    readonly property real targetTrayIslandHeight: trayMenuOpen ? trayMenuTargetHeight : 0

    property real trayIslandWidth: 44
    property real trayIslandHeight: 0
    property real smoothTrayIslandHeight: targetTrayIslandHeight

    Behavior on smoothTrayIslandHeight { NumberAnimation { duration: root.animDur(360, 265); easing.type: root.animPrimaryEase } }

    readonly property real trayIslandDeformScaleY: Math.max(0.86, Math.min(1.12, trayIslandHeight / Math.max(1, smoothTrayIslandHeight)))

    ParallelAnimation {
        id: trayOpenAnim
        alwaysRunToEnd: false

        SequentialAnimation {
            NumberAnimation {
                id: trayOpenW1Anim
                target: root
                property: "trayIslandWidth"
                to: root.trayMenuTargetWidth * (root.isSnappyAnimations ? 1.018 : 1.014)
                duration: root.animDur(360, 245)
                easing.type: root.animPrimaryEase
            }
            NumberAnimation {
                id: trayOpenW2Anim
                target: root
                property: "trayIslandWidth"
                to: root.trayMenuTargetWidth
                duration: root.animDur(200, 165)
                easing.type: Easing.InOutSine
            }
        }
        SequentialAnimation {
            NumberAnimation {
                id: trayOpenH1Anim
                target: root
                property: "trayIslandHeight"
                to: root.trayMenuTargetHeight * (root.isSnappyAnimations ? 1.022 : 1.016)
                duration: root.animDur(360, 260)
                easing.type: root.animPrimaryEase
            }
            NumberAnimation {
                id: trayOpenH2Anim
                target: root
                property: "trayIslandHeight"
                to: root.trayMenuTargetHeight
                duration: root.animDur(200, 165)
                easing.type: Easing.InOutSine
            }
        }
    }

    ParallelAnimation {
        id: trayCloseAnim
        alwaysRunToEnd: false

        NumberAnimation {
            id: trayCloseWidthAnim
            target: root
            property: "trayIslandWidth"
            to: root.trayCollapsedWidth
            duration: root.animDur(320, 200)
            easing.type: root.animPrimaryEase
        }
        NumberAnimation {
            id: trayCloseHeightAnim
            target: root
            property: "trayIslandHeight"
            to: 0
            duration: root.animDur(320, 200)
            easing.type: root.animPrimaryEase
        }
    }

    ParallelAnimation {
        id: trayResizeAnim
        alwaysRunToEnd: false

        NumberAnimation {
            id: trayResizeWidthAnim
            target: root
            property: "trayIslandWidth"
            to: root.trayMenuTargetWidth
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: trayResizeHeightAnim
            target: root
            property: "trayIslandHeight"
            to: root.trayMenuTargetHeight
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    function triggerTrayIslandMorph() {
        if (!root.trayMenuOpen) {
            trayOpenAnim.stop();
            trayResizeAnim.stop();
            trayCloseWidthAnim.from = root.trayIslandWidth;
            trayCloseWidthAnim.to = root.trayCollapsedWidth;
            trayCloseHeightAnim.from = root.trayIslandHeight;
            trayCloseHeightAnim.to = 0;
            trayCloseAnim.restart();
            return;
        }

        trayCloseAnim.stop();
        if (root.trayIslandHeight > 6 && !trayOpenAnim.running) {
            trayResizeWidthAnim.to = root.trayMenuTargetWidth;
            trayResizeHeightAnim.to = root.trayMenuTargetHeight;
            trayResizeAnim.restart();
        } else {
            trayResizeAnim.stop();
            trayOpenAnim.stop();
            trayOpenW1Anim.to = root.trayMenuTargetWidth * 1.018;
            trayOpenW2Anim.to = root.trayMenuTargetWidth;
            trayOpenH1Anim.to = root.trayMenuTargetHeight * 1.022;
            trayOpenH2Anim.to = root.trayMenuTargetHeight;
            trayOpenAnim.restart();
        }
    }

    onTrayMenuTargetWidthChanged: {
        if (trayMenuOpen) triggerTrayIslandMorph();
    }
    onTrayMenuTargetHeightChanged: {
        if (trayMenuOpen) triggerTrayIslandMorph();
    }

    Timer {
        id: notifHideTimer
        interval: root.notifTimeoutSec * 1000
        repeat: false
        onTriggered: {
            root.notifOpen = false;
            root.activeNotifsModel.clear();
        }
    }

    function processNotification(notif) {
        if (!notif) return;
        try {
            notif.tracked = true;
        } catch (e) {}

        root.notifSummary = notif.summary || "";
        root.notifBody = notif.body || "";
        root.notifAppName = notif.appName || "Notification";
        root.notifAppIcon = notif.appIcon || "";
        root.notifImage = notif.image || "";

        let iconName = notif.appIcon || "";
        let imgPath = notif.image || "";

        if (imgPath.startsWith("image://icon/")) {
            iconName = imgPath.slice(13);
            imgPath = "";
        }

        let notifIconSrc = "";
        let notifIsFileImg = false;

        if (imgPath && (imgPath.startsWith("file://") || imgPath.startsWith("/"))) {
            notifIconSrc = imgPath.startsWith("file://") ? imgPath : ("file://" + imgPath);
            notifIsFileImg = true;
        } else if (iconName && (iconName.startsWith("file://") || iconName.startsWith("/"))) {
            notifIconSrc = iconName.startsWith("file://") ? iconName : ("file://" + iconName);
            notifIsFileImg = true;
        } else if (iconName && iconName.length > 0) {
            notifIconSrc = iconName;
            notifIsFileImg = false;
        } else if (notif.desktopEntry) {
            notifIconSrc = notif.desktopEntry;
            notifIsFileImg = false;
        } else if (notif.appName) {
            notifIconSrc = notif.appName.toLowerCase();
            notifIsFileImg = false;
        }

        root.notifIconSrc = notifIconSrc;
        root.notifIsFileImg = notifIsFileImg;

        // Add to persistent notification history
        const now = new Date();
        const timeStr = Qt.formatTime(now, "hh:mm");
        const notifEntry = {
            notifId: (notif.id !== undefined && notif.id !== null) ? Number(notif.id) : Date.now(),
            appName: root.notifAppName,
            summary: root.notifSummary.length > 0 ? root.notifSummary : "Notification",
            body: root.notifBody,
            time: timeStr,
            iconSrc: notifIconSrc,
            isFileImg: notifIsFileImg,
            desktopEntry: notif.desktopEntry || "",
            rawNotif: notif
        };

        notifHistoryModel.insert(0, notifEntry);
        while (notifHistoryModel.count > 50) {
            notifHistoryModel.remove(notifHistoryModel.count - 1);
        }

        // If Do Not Disturb is active or Notification Center is already open, don't popup active banner
        if (root.dndActive || root.notifCenterOpen) {
            return;
        }

        // Add to active popup stack (max 2): newest at index 0, pushing previous down to index 1!
        activeNotifsModel.insert(0, notifEntry);
        while (activeNotifsModel.count > 2) {
            activeNotifsModel.remove(activeNotifsModel.count - 1);
        }

        if (!root.notifOpen) {
            root.notifOpen = true;
        } else {
            notifOpenAnim.stop();
            notifHeightExpandAnim.to = root.targetNotifHeight;
            notifHeightExpandAnim.restart();
        }
    }

    Connections {
        target: root.notifServer
        function onNotification(notif) {
            root.processNotification(notif);
        }
    }

    Timer {
        id: volumeHideTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.volumeOsdOpen = false;
        }
    }

    onLauncherOpenChanged: {
        if (launcherOpen) {
            clipboardOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            powerOsdOpen = false;
            volumeOsdOpen = false;
        }
    }

    onSettingsOpenChanged: {
        if (settingsOpen) {
            launcherOpen = false;
            clipboardOpen = false;
            cheatSheetOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            powerOsdOpen = false;
        }
    }

    onCheatSheetOpenChanged: {
        if (cheatSheetOpen) {
            launcherOpen = false;
            clipboardOpen = false;
            settingsOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            powerOsdOpen = false;
        }
    }

    onControlCenterOpenChanged: {
        if (controlCenterOpen) {
            root.launcherOpen = false;
            root.clipboardOpen = false;
            root.settingsOpen = false;
            root.cheatSheetOpen = false;
            root.mediaToastOpen = false;
            root.volumeOsdOpen = false;
            root.powerOsdOpen = false;
            root.notifCenterOpen = false;
            root.notifOpen = false;
            root.weatherOpen = false;
            root.sysMenuOpen = false;
            root.trayMenuOpen = false;
            ccCloseAnim.stop();
            ccOpenAnim.restart();
        } else {
            root.powerMenuOpen = false;
            root.networkExtended = false;
            root.bluetoothExtended = false;
            root.audioExtended = false;
            ccOpenAnim.stop();
            ccCloseHeightAnim.from = ccHeight;
            ccCloseWidthAnim.from = ccWidth;
            ccCloseAnim.restart();
        }
    }

    onNotifCenterOpenChanged: {
        if (notifCenterOpen) {
            root.notifCenterOpenedAt = Date.now();
            root.isClearingHistory = false;
            clearFinishTimer.stop();
            root.rightIslandOwner = "notifCenter";
            root.notifOpen = false;
            root.activeNotifsModel.clear();
            notifCloseAnim.stop();
            root.notifHeight = 0;
            root.notifWidth = 0;
            root.controlCenterOpen = false;
            root.weatherOpen = false;
            root.sysMenuOpen = false;
            root.trayMenuOpen = false;
            root.launcherOpen = false;
            root.settingsOpen = false;
            root.cheatSheetOpen = false;
        }
        triggerRightIslandMorph();
    }

    onVolumeOsdOpenChanged: {
        if (volumeOsdOpen) {
            root.mediaToastOpen = false;
            volumeCloseAnim.stop();
            volumeOpenAnim.restart();
        } else {
            volumeOpenAnim.stop();
            volumeCloseWidthAnim.from = volumeOsdWidth;
            volumeCloseAnim.restart();
        }
    }

    onNotifOpenChanged: {
        if (notifOpen) {
            root.mediaToastOpen = false;
            root.volumeOsdOpen = false;
            notifCloseAnim.stop();
            notifOpenAnim.restart();
        } else {
            notifOpenAnim.stop();
            notifHeightExpandAnim.stop();
            notifCloseHeightAnim.from = notifHeight;
            notifCloseWidthAnim.from = notifWidth;
            notifCloseAnim.restart();
        }
    }

    onSysMenuOpenChanged: {
        if (sysMenuOpen) {
            launcherOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
        }
        triggerLeftIslandMorph();
    }

    onWeatherOpenChanged: {
        if (weatherOpen) {
            root.rightIslandOwner = "weather";
            launcherOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            sysMenuOpen = false;
            trayMenuOpen = false;
        }
        triggerRightIslandMorph();
    }

    onTrayMenuOpenChanged: {
        if (trayMenuOpen) {
            launcherOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
            powerOsdOpen = false;
            clipboardOpen = false;
            if (root.trayIslandHeight <= 1) {
                root.trayIslandWidth = root.trayCollapsedWidth;
                root.trayIslandHeight = 0;
            }
        }
        triggerTrayIslandMorph();
    }

    onPowerOsdOpenChanged: {
        if (powerOsdOpen) {
            launcherOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            notifOpen = false;
            mediaToastOpen = false;
            volumeOsdOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
            clipboardOpen = false;
            powerOsdCloseAnim.stop();
            powerOsdOpenAnim.restart();
        } else {
            powerOsdOpenAnim.stop();
            powerOsdCloseWidthAnim.from = powerOsdWidth;
            powerOsdCloseAnim.restart();
        }
    }

    onClipboardOpenChanged: {
        if (clipboardOpen) {
            launcherOpen = false;
            controlCenterOpen = false;
            notifCenterOpen = false;
            volumeOsdOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
            powerOsdOpen = false;
        }
    }

    function togglePowerOsd() {
        if (root.locked) return;
        if (!powerOsdOpen) activateFocusedMonitorIfIdle();
        powerOsdOpen = !powerOsdOpen;
        if (powerOsdOpen) {
            controlCenterOpen = false;
        notifCenterOpen = false;
            volumeOsdOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            clipboardOpen = false;
            launcherOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    function toggleClipboard() {
        if (root.locked) return;
        if (!clipboardOpen) activateFocusedMonitorIfIdle();
        clipboardOpen = !clipboardOpen;
        if (clipboardOpen) {
            launcherOpen = false;
            controlCenterOpen = false;
        notifCenterOpen = false;
            powerOsdOpen = false;
            volumeOsdOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    function toggleSysMenu() {
        if (root.locked) return;
        if (!sysMenuOpen) activateFocusedMonitorIfIdle();
        sysMenuOpen = !sysMenuOpen;
        if (sysMenuOpen) {
            launcherOpen = false;
            controlCenterOpen = false;
        notifCenterOpen = false;
            weatherOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    function toggleWeather() {
        if (root.locked) return;
        if (!weatherOpen) activateFocusedMonitorIfIdle();
        weatherOpen = !weatherOpen;
        if (weatherOpen) {
            sysMenuOpen = false;
            launcherOpen = false;
            controlCenterOpen = false;
        notifCenterOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    property bool cheatSheetOpen: false

    function toggleCheatSheet() {
        if (root.locked) return;
        if (!cheatSheetOpen) activateFocusedMonitorIfIdle();
        cheatSheetOpen = !cheatSheetOpen;
        if (cheatSheetOpen) {
            sysMenuOpen = false;
            weatherOpen = false;
            controlCenterOpen = false;
        notifCenterOpen = false;
            launcherOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
        }
    }

    function toggleSettings() {
        if (root.locked) return;
        if (!settingsOpen) activateFocusedMonitorIfIdle();
        settingsOpen = !settingsOpen;
        if (settingsOpen) {
            sysMenuOpen = false;
            weatherOpen = false;
            controlCenterOpen = false;
        notifCenterOpen = false;
            launcherOpen = false;
            trayMenuOpen = false;
            cheatSheetOpen = false;
        }
    }

    function toggleLauncher() {
        if (root.locked) return;
        if (!launcherOpen) activateFocusedMonitorIfIdle();
        launcherOpen = !launcherOpen;
        if (launcherOpen) {
            sysMenuOpen = false;
            weatherOpen = false;
            controlCenterOpen = false;
        notifCenterOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    function toggleControlCenter() {
        if (root.locked) return;
        if (!controlCenterOpen) activateFocusedMonitorIfIdle();
        controlCenterOpen = !controlCenterOpen;
        if (controlCenterOpen) {
            notifCenterOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            launcherOpen = false;
            volumeOsdOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    function toggleNotifCenter() {
        if (root.locked) return;
        if (!notifCenterOpen) activateFocusedMonitorIfIdle();
        notifCenterOpen = !notifCenterOpen;
        if (notifCenterOpen) {
            controlCenterOpen = false;
            sysMenuOpen = false;
            weatherOpen = false;
            launcherOpen = false;
            trayMenuOpen = false;
            settingsOpen = false;
            cheatSheetOpen = false;
        }
    }

    Timer {
        id: kbHideTimer
        interval: 1700
        repeat: false
        onTriggered: {
            root.kbOsdOpen = false;
        }
    }

    function triggerKeyboardOsd() {
        if (root.locked) return;
        if (!controlCenterOpen && !powerOsdOpen && !launcherOpen && !clipboardOpen && !settingsOpen && !cheatSheetOpen) {
            activateFocusedMonitorIfIdle();
            mediaToastOpen = false;
            volumeOsdOpen = false;
            kbOsdOpen = true;
            kbHideTimer.restart();
        }
    }

    function nextKeyboardLayout() {
        root.kbSwitchPending = true;
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function triggerVolumeOsd() {
        if (!controlCenterOpen && !powerOsdOpen && !sysMenuOpen && !weatherOpen && !trayMenuOpen) {
            kbOsdOpen = false;
            volumeOsdOpen = true;
            volumeHideTimer.restart();
        }
    }

    function pauseVolumeOsdTimer() {
        volumeHideTimer.stop();
    }

    function resumeVolumeOsdTimer() {
        if (volumeOsdOpen) {
            volumeHideTimer.restart();
        }
    }

    function dismissNotification() {
        notifHideTimer.stop();
        notifOpen = false;
    }

    function triggerTestNotification() {
        Quickshell.execDetached(["notify-send", "-a", "Discord", "-i", "discord", "Lorem Ipsum", "Lorem ipsum dolor sit amet, consectetur adipiscing elit."]);
    }

    function closeAll() {
        sysMenuOpen = false;
        weatherOpen = false;
        trayMenuOpen = false;
        launcherOpen = false;
        controlCenterOpen = false;
        notifCenterOpen = false;
        volumeOsdOpen = false;
        kbOsdOpen = false;
        powerOsdOpen = false;
        clipboardOpen = false;
        notifOpen = false;
        powerMenuOpen = false;
        networkExtended = false;
        bluetoothExtended = false;
        audioExtended = false;
        settingsOpen = false;
        cheatSheetOpen = false;
    }

    function lockScreen() {
        closeAll();
        root.locked = true;
        root.lockVisualOpen = true;
    }

    function unlockScreen() {
        root.locked = false;
        root.lockVisualOpen = false;
    }

    // PipeWire Sink Tracking for Volume Adjustments
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    property real lastKnownVolume: -1
    property bool lastKnownMuted: false
    property bool volumeTrackerInitialized: false

    Timer {
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                root.lastKnownVolume = sink.audio.volume;
                root.lastKnownMuted = sink.audio.muted;
            }
            root.volumeTrackerInitialized = true;
        }
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (!root.volumeTrackerInitialized) return;
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                if (Math.abs(sink.audio.volume - root.lastKnownVolume) > 0.005) {
                    root.lastKnownVolume = sink.audio.volume;
                    root.triggerVolumeOsd();
                }
            }
        }
        function onMutedChanged() {
            if (!root.volumeTrackerInitialized) return;
            const sink = Pipewire.defaultAudioSink;
            if (sink && sink.audio) {
                root.lastKnownMuted = sink.audio.muted;
                root.triggerVolumeOsd();
            }
        }
    }
}
