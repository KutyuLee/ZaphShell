import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Item {
    id: root

    property var targetScreen: null
    property bool ownsActivePanel: true
    readonly property int activeWsId: root.targetScreen
        ? ShellState.activeWorkspaceIdForScreen(root.targetScreen)
        : ((Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) ? Hyprland.focusedWorkspace.id : 1)
    // Dynamically shifts workspace bank in groups of 5 (1-5, 6-10, 11-15, ...)
    readonly property int baseIndex: Math.floor((activeWsId - 1) / 5) * 5
    readonly property var allToplevels: (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : []

    property real expandedExtraWidth: 0
    readonly property real targetWidth: 110 + expandedExtraWidth
    readonly property bool isPillHighlighted: expandedExtraWidth > 0.5

    implicitHeight: 26
    implicitWidth: Math.max(110, wsRow.implicitWidth)
    width: implicitWidth
    height: 26

    function workspaceObject(id) {
        if (!Hyprland.workspaces || !Hyprland.workspaces.values) return null;
        for (let i = 0; i < Hyprland.workspaces.values.length; ++i) {
            const ws = Hyprland.workspaces.values[i];
            if (ws && ws.id === id) return ws;
        }
        return null;
    }

    function isOccupied(id) {
        const ws = workspaceObject(id);
        if (!ws) return false;
        if (ws.lastIpcObject && ws.lastIpcObject.windows !== undefined) {
            return Number(ws.lastIpcObject.windows) > 0;
        }
        return (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0) ? true : false;
    }

    function getToplevelWsId(top) {
        if (!top) return -1;
        if (top.workspace && top.workspace.id !== undefined && top.workspace.id !== null) {
            return Number(top.workspace.id);
        }
        if (top.lastIpcObject && top.lastIpcObject.workspace && top.lastIpcObject.workspace.id !== undefined) {
            return Number(top.lastIpcObject.workspace.id);
        }
        return -1;
    }

    function resolveAppIcon(top) {
        if (!top) return "application-x-executable";
        let rawClass = "";
        if (top.wayland && top.wayland.appId) {
            rawClass = String(top.wayland.appId);
        } else if (top.lastIpcObject && top.lastIpcObject["class"]) {
            rawClass = String(top.lastIpcObject["class"]);
        } else if (top.lastIpcObject && top.lastIpcObject["initialClass"]) {
            rawClass = String(top.lastIpcObject["initialClass"]);
        }
        if (rawClass) {
            const entry = DesktopEntries.heuristicLookup(rawClass);
            if (entry && entry.icon) return String(entry.icon);
            return rawClass.toLowerCase();
        }
        return "application-x-executable";
    }

    function getWorkspaceApps(id) {
        const result = [];
        const seen = {};
        const ws = workspaceObject(id);
        const wsList = (ws && ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : [];
        const allList = root.allToplevels;

        for (let i = 0; i < wsList.length; ++i) {
            const top = wsList[i];
            if (!top) continue;
            const topWsId = getToplevelWsId(top);
            if (topWsId > 0 && topWsId !== id) continue;
            const addr = top.address ? String(top.address) : ("ws_" + i);
            if (seen[addr]) continue;
            seen[addr] = true;
            result.push({
                icon: resolveAppIcon(top),
                address: top.address ? String(top.address) : "",
                title: top.title ? String(top.title) : ""
            });
            if (result.length >= 6) return result;
        }

        for (let i = 0; i < allList.length; ++i) {
            const top = allList[i];
            if (!top) continue;
            if (getToplevelWsId(top) !== id) continue;
            const addr = top.address ? String(top.address) : ("all_" + i);
            if (seen[addr]) continue;
            seen[addr] = true;
            result.push({
                icon: resolveAppIcon(top),
                address: top.address ? String(top.address) : "",
                title: top.title ? String(top.title) : ""
            });
            if (result.length >= 6) break;
        }
        return result;
    }

    function switchToWorkspace(targetId) {
        const clamped = Math.max(1, targetId);
        ShellState.dispatchHypr("hl.dsp.focus({ workspace = " + clamped + " })", "workspace " + clamped);
    }

    function focusWindow(address, fallbackWsId) {
        if (address && address.length > 0) {
            ShellState.dispatchHypr("hl.dsp.focus({ window = 'address:" + address + "' })", "focuswindow address:" + address);
        } else {
            switchToWorkspace(fallbackWsId);
        }
    }

    HoverHandler {
        id: rowHover
        onHoveredChanged: {
            if (!hovered) Qt.callLater(root.updateExpandedExtra);
        }
    }

    // Mouse wheel scroll to cycle workspaces
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y > 0) {
                root.switchToWorkspace(root.activeWsId - 1);
            } else if (event.angleDelta.y < 0) {
                root.switchToWorkspace(root.activeWsId + 1);
            }
            event.accepted = true;
        }
    }

    Row {
        id: wsRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        leftPadding: 1
        rightPadding: 1
        spacing: 2

        Repeater {
            id: wsRepeater
            model: 5

            delegate: Item {
                id: wsSlot
                required property int index
                readonly property int wsId: root.baseIndex + index + 1
                readonly property bool isFocused: root.activeWsId === wsId
                readonly property var wsApps: root.getWorkspaceApps(wsId)
                readonly property bool hasApps: wsApps.length > 0
                readonly property bool occupied: hasApps || root.isOccupied(wsId)
                readonly property bool isPillExpanded: rowHover.hovered && wsHover.hovered && hasApps && (!root.ownsActivePanel || !ShellState.sysMenuOpen)

                readonly property real expandedWidth: 20 + 2 + wsApps.length * 18 + 4
                readonly property real targetSlotWidth: isPillExpanded ? expandedWidth : 20

                property real animatedSlotWidth: 20
                onTargetSlotWidthChanged: {
                    slotWidthAnim.stop();
                    slotWidthAnim.to = targetSlotWidth;
                    slotWidthAnim.restart();
                    root.updateExpandedExtra();
                }

                NumberAnimation {
                    id: slotWidthAnim
                    target: wsSlot
                    property: "animatedSlotWidth"
                    duration: ShellState.animDur(320, 220)
                    easing.type: ShellState.animPrimaryEase
                }

                width: animatedSlotWidth
                height: 22

                HoverHandler {
                    id: wsHover
                }

                // Hover pill formed around this active workspace expanding rightward to reveal open app icons
                Rectangle {
                    id: pillBg
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: wsSlot.animatedSlotWidth
                    height: 22
                    radius: 11
                    clip: true
                    color: wsPillLg.isLiquidActive ? "transparent" : (wsSlot.isPillExpanded ? Theme.glassSurfaceHover : "transparent")
                    border.width: wsPillLg.isLiquidActive ? 0 : (wsSlot.isPillExpanded ? 1 : 0)
                    border.color: wsSlot.isPillExpanded ? Theme.glassBorder : "transparent"

                    LiquidGlassSurface {
                        id: wsPillLg
                        anchors.fill: parent
                        z: -1
                        cornerRadius: 11
                        hovered: wsSlot.isPillExpanded
                        onlyWhenHighlighted: true
                    }

                    Behavior on color { ColorAnimation { duration: 160 } }

                    // Fixed left 20x22 dot container so the workspace indicator never shifts horizontally
                    Item {
                        id: dotContainer
                        x: 0
                        y: 0
                        width: 20
                        height: 22

                        // Animated Dot (Empty/Occupied) <-> Square (Focused) Indicator
                        Rectangle {
                            id: indicator
                            anchors.centerIn: parent
                            width: wsSlot.isFocused ? 12 : (wsSlot.occupied ? 8 : 5)
                            height: wsSlot.isFocused ? 12 : (wsSlot.occupied ? 8 : 5)
                            radius: wsSlot.isFocused ? 3 : (wsSlot.occupied ? 4 : 2.5)

                            color: {
                                if (wsSlot.isFocused) return Theme.text;
                                if (wsHover.hovered) return Theme.text;
                                if (wsSlot.occupied) return Theme.text;
                                return Theme.textDim;
                            }

                            opacity: {
                                if (wsSlot.isFocused) return 1.0;
                                if (wsHover.hovered) return 1.0;
                                if (wsSlot.occupied) return 0.90;
                                return 0.35;
                            }

                            border.width: wsSlot.isFocused ? 1 : 0
                            border.color: wsSlot.isFocused ? Theme.text : "transparent"

                            scale: dotMouse.pressed ? 0.82 : (wsHover.hovered ? 1.14 : 1.0)

                            Behavior on width { NumberAnimation { duration: ShellState.animDur(280, 200); easing.type: ShellState.animPrimaryEase } }
                            Behavior on height { NumberAnimation { duration: ShellState.animDur(280, 200); easing.type: ShellState.animPrimaryEase } }
                            Behavior on radius { NumberAnimation { duration: ShellState.animDur(260, 180); easing.type: ShellState.animPrimaryEase } }
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(200, 140); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 160) } }
                            Behavior on opacity { NumberAnimation { duration: ShellState.animDur(220, 160) } }
                        }

                        MouseArea {
                            id: dotMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchToWorkspace(wsSlot.wsId)
                        }
                    }

                    // Right-expanding row of open application icons for this active workspace
                    Row {
                        id: appsRow
                        x: 21
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        opacity: wsSlot.isPillExpanded ? 1.0 : 0.0
                        visible: wsSlot.animatedSlotWidth > 22

                        Behavior on opacity {
                            NumberAnimation { duration: ShellState.animDur(240, 160); easing.type: ShellState.animPrimaryEase }
                        }

                        Repeater {
                            model: wsSlot.wsApps

                            delegate: Item {
                                id: appIconSlot
                                required property var modelData
                                width: 16
                                height: 18

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 5
                                    color: appMouse.containsMouse ? Theme.glassSurfaceActive : "transparent"
                                    scale: appMouse.pressed ? 0.86 : (appMouse.containsMouse ? 1.10 : 1.0)

                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    IconImage {
                                        id: appImg
                                        anchors.centerIn: parent
                                        width: 14
                                        height: 14
                                        source: appIconSlot.modelData && appIconSlot.modelData.icon ? Quickshell.iconPath(appIconSlot.modelData.icon) : ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: appImg.status !== Image.Ready
                                        text: "󰵆"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 11
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.focusWindow(appIconSlot.modelData.address, wsSlot.wsId);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function updateExpandedExtra() {
        let extra = 0;
        for (let i = 0; i < wsRepeater.count; ++i) {
            const it = wsRepeater.itemAt(i);
            if (it && it.targetSlotWidth > 20) {
                extra += (it.targetSlotWidth - 20);
            }
        }
        root.expandedExtraWidth = extra;
    }
}
