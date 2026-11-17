import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

// Reusable 0x0 clipped offscreen compositor (wallpaper + live Hyprland toplevels on main monitor)
// feeding ShaderEffectSource without ever painting over desktop windows on WlrLayer.Top/Overlay.
Item {
    id: root

    property bool active: false
    property var targetScreen: null
    property real sceneWidth: ShellState.mainScreenWidth
    property real sceneHeight: ShellState.mainScreenHeight
    property int settleTicks: 0

    property var waylandByKey: ({})

    readonly property var captureWindows: {
        const _rev = ShellState.desktopLayoutRev;
        return root.targetScreen ? ShellState.desktopWindowsForScreen(root.targetScreen) : ShellState.mainDesktopWindows;
    }
    onCaptureWindowsChanged: {
        syncWinModel();
        if (root.active) root.triggerSettle();
    }

    ListModel {
        id: winModel
    }

    function syncWinModel() {
        if (!root.active) {
            if (winModel.count > 0) winModel.clear();
            root.waylandByKey = ({});
            return;
        }
        const wins = root.captureWindows || [];
        const nextMap = {};
        const keepSet = {};
        for (let i = 0; i < wins.length; ++i) {
            const w = wins[i];
            nextMap[w.winKey] = w.wayland;
            keepSet[w.winKey] = true;
        }
        root.waylandByKey = nextMap;

        for (let i = winModel.count - 1; i >= 0; --i) {
            if (!keepSet[winModel.get(i).winKey]) winModel.remove(i, 1);
        }

        for (let targetIdx = 0; targetIdx < wins.length; ++targetIdx) {
            const w = wins[targetIdx];
            let foundIdx = -1;
            for (let j = targetIdx; j < winModel.count; ++j) {
                if (winModel.get(j).winKey === w.winKey) {
                    foundIdx = j;
                    break;
                }
            }
            if (foundIdx >= 0) {
                if (foundIdx !== targetIdx) winModel.move(foundIdx, targetIdx, 1);
                const cur = winModel.get(targetIdx);
                if (cur.winX !== w.winX) winModel.setProperty(targetIdx, "winX", w.winX);
                if (cur.winY !== w.winY) winModel.setProperty(targetIdx, "winY", w.winY);
                if (cur.winW !== w.winW) winModel.setProperty(targetIdx, "winW", w.winW);
                if (cur.winH !== w.winH) winModel.setProperty(targetIdx, "winH", w.winH);
                if (cur.winZ !== w.winZ) winModel.setProperty(targetIdx, "winZ", w.winZ);
            } else {
                winModel.insert(targetIdx, {
                    winKey: w.winKey,
                    winX: w.winX,
                    winY: w.winY,
                    winW: w.winW,
                    winH: w.winH,
                    winZ: w.winZ
                });
            }
        }
    }

    readonly property alias textureSource: bgSource
    readonly property bool ready: bgImage.status === Image.Ready

    width: 0
    height: 0

    function triggerSettle() {
        if (!root.active) return;
        root.settleTicks = 8;
        settleTimer.restart();
        Qt.callLater(bgSource.scheduleUpdate);
    }

    function refreshNow() {
        if (!root.active) return;
        syncWinModel();
        triggerSettle();
    }

    Component.onCompleted: {
        syncWinModel();
        if (root.active) {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
            startupSettleTimer.restart();
            triggerSettle();
        }
    }

    onSceneWidthChanged: if (root.active) triggerSettle()
    onSceneHeightChanged: if (root.active) triggerSettle()

    onActiveChanged: {
        syncWinModel();
        if (active) {
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
            startupSettleTimer.restart();
            triggerSettle();
        } else {
            startupSettleTimer.stop();
            settleTimer.stop();
            root.settleTicks = 0;
        }
    }

    Timer {
        id: startupSettleTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (root.active) {
                ShellState.scheduleDesktopRefresh(6);
                root.refreshNow();
            }
        }
    }

    Timer {
        id: settleTimer
        interval: 60
        repeat: true
        onTriggered: {
            for (let i = 0; i < winRepeater.count; ++i) {
                const it = winRepeater.itemAt(i);
                if (it && it.retryIfEmpty && it.retryIfEmpty()) {
                    root.settleTicks = Math.max(root.settleTicks, 4);
                }
            }
            bgSource.scheduleUpdate();
            if (root.settleTicks > 0) {
                root.settleTicks--;
            } else {
                stop();
            }
        }
    }

    Connections {
        target: ShellState
        enabled: root.active
        function onMainDesktopWindowsChanged() {
            root.triggerSettle();
        }
        function onWallpaperPathChanged() {
            root.triggerSettle();
        }
    }

    Item {
        width: 0
        height: 0
        clip: true
        visible: root.active

        Item {
            id: desktopScene
            x: 0
            y: 0
            width: Math.max(1, root.sceneWidth)
            height: Math.max(1, root.sceneHeight)

            Image {
                id: bgImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                source: (root.active && ShellState.wallpaperPath && ShellState.wallpaperPath.length > 0)
                    ? ("file://" + ShellState.wallpaperPath)
                    : ""
                onStatusChanged: {
                    if (status === Image.Ready) root.triggerSettle();
                }
                onWidthChanged: if (status === Image.Ready) root.triggerSettle()
                onHeightChanged: if (status === Image.Ready) root.triggerSettle()
            }

            Repeater {
                id: winRepeater
                model: winModel

                delegate: ScreencopyView {
                    required property string winKey
                    required property real winX
                    required property real winY
                    required property real winW
                    required property real winH
                    required property real winZ
                    property bool forceRebind: false
                    property int rebindCount: 0
                    function retryIfEmpty() {
                        if (!hasContent && root.active && root.waylandByKey[winKey] && rebindCount < 6) {
                            rebindCount++;
                            forceRebind = true;
                            Qt.callLater(function() { forceRebind = false; });
                            return true;
                        }
                        return false;
                    }
                    captureSource: forceRebind ? null : (root.waylandByKey[winKey] || null)
                    live: root.active
                    x: winX
                    y: winY
                    width: Math.max(1, winW)
                    height: Math.max(1, winH)
                    z: winZ
                    onHasContentChanged: {
                        if (hasContent) rebindCount = 0;
                        root.triggerSettle();
                    }
                }
            }
        }
    }

    ShaderEffectSource {
        id: bgSource
        visible: false
        sourceItem: desktopScene
        hideSource: true
        live: root.active
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(root.sceneWidth)), Math.max(1, Math.round(root.sceneHeight)))
        onSourceItemChanged: if (root.active) root.triggerSettle()
    }
}
