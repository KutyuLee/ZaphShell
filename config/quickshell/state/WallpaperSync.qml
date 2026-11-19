import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: wallSync

    required property var shellState

    Process {
        id: hyprpaperQueryProc
        command: [wallSync.shellState.script("wallpaper.sh"), "current", Theme.mainMonitorName]
        stdout: SplitParser {
            onRead: data => {
                const p = String(data || "").trim();
                if (p.length > 0 && p !== wallSync.shellState.wallpaperPath) {
                    wallSync.shellState.wallpaperPath = p;
                }
            }
        }
    }

    function sync() {
        hyprpaperQueryProc.running = false;
        hyprpaperQueryProc.running = true;
    }

    function apply(newPath) {
        if (!newPath || newPath.length === 0) return;
        wallSync.shellState.wallpaperPath = newPath;
        hyprpaperSyncTimer.pendingWall = newPath;
        hyprpaperSyncTimer.restart();
    }

    function resetToDefault() {
        wallSync.shellState.wallpaperPath = wallSync.shellState.defaultWallpaperPath;
        Quickshell.execDetached([wallSync.shellState.script("wallpaper.sh"), "default"]);
        Qt.callLater(sync);
    }

    Timer {
        id: hyprpaperPollTimer
        interval: 8000
        repeat: true
        running: !wallSync.shellState.locked
        triggeredOnStart: true
        onTriggered: wallSync.sync()
    }

    Timer {
        id: hyprpaperSyncTimer
        interval: 50
        repeat: false
        property string pendingWall: ""
        onTriggered: {
            if (pendingWall && pendingWall.length > 0) {
                Quickshell.execDetached([wallSync.shellState.script("wallpaper.sh"), "set", pendingWall]);
            }
        }
    }
}
