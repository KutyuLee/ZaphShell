import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import ".."

Rectangle {
    id: root

    // Gather active and running scratchpads from Hyprland
    readonly property var activeScratchpads: {
        const list = [];
        if (!Hyprland.workspaces || !Hyprland.workspaces.values) return list;

        const known = {
            "magic": { name: "magic", label: "Special", icon: "󰵉", color: Theme.accent },
            "special": { name: "magic", label: "Special", icon: "󰵉", color: Theme.accent },
            "sysmon": { name: "sysmon", label: "Sysmon", icon: "󰍛", color: "#68d391" },
            "music": { name: "music", label: "Music", icon: "󰝚", color: "#63b3ed" },
            "comm": { name: "comm", label: "Comm", icon: "󰭹", color: "#f6ad55" }
        };

        const added = {};

        // 1. Check existing special workspaces in Hyprland
        for (let i = 0; i < Hyprland.workspaces.values.length; ++i) {
            const ws = Hyprland.workspaces.values[i];
            if (!ws || !ws.name) continue;

            let sName = "";
            if (ws.name.startsWith("special:")) {
                sName = ws.name.substring(8);
            } else if (ws.name === "special") {
                sName = "magic";
            }

            if (sName.length > 0) {
                const info = known[sName] || {
                    name: sName,
                    label: sName.charAt(0).toUpperCase() + sName.slice(1),
                    icon: "󰘳",
                    color: Theme.accent
                };

                const winCount = (ws.lastIpcObject && ws.lastIpcObject.windows !== undefined) ? ws.lastIpcObject.windows : 1;
                // Check if this scratchpad is currently active on any monitor
                let isCurrentlyOpen = false;
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.lastIpcObject) {
                    const spObj = Hyprland.focusedMonitor.lastIpcObject.specialWorkspace;
                    if (spObj && spObj.name === ws.name) {
                        isCurrentlyOpen = true;
                    }
                }

                if (!added[sName]) {
                    added[sName] = true;
                    list.push({
                        name: sName,
                        fullName: ws.name,
                        label: info.label,
                        icon: info.icon,
                        accentColor: info.color,
                        windowCount: winCount,
                        isOpen: isCurrentlyOpen
                    });
                }
            }
        }
        return list;
    }

    readonly property int count: activeScratchpads.length
    property int hoveredCount: 0
    readonly property bool isPillHighlighted: {
        if (hoveredCount > 0) return true;
        for (let i = 0; i < activeScratchpads.length; ++i) {
            if (activeScratchpads[i].isOpen) return true;
        }
        return false;
    }
    readonly property real targetWidth: count > 0 ? (count * 22 + Math.max(0, count - 1) * 3) : 0
    visible: count > 0

    implicitHeight: 26
    implicitWidth: count > 0 ? row.implicitWidth : 0
    radius: 0
    color: "transparent"
    border.width: 0

    opacity: count > 0 ? 1.0 : 0.0
    scale: count > 0 ? 1.0 : 0.90

    Behavior on implicitWidth {
        NumberAnimation { duration: ShellState.animDur(320, 240); easing.type: ShellState.animPrimaryEase }
    }
    Behavior on opacity {
        NumberAnimation { duration: ShellState.animDur(280, 220); easing.type: ShellState.animPrimaryEase }
    }
    Behavior on scale {
        NumberAnimation {
            duration: ShellState.animDur(300, 220)
            easing.type: ShellState.isSnappyAnimations ? Easing.OutBack : Easing.InOutCubic
            easing.overshoot: ShellState.isSnappyAnimations ? 1.1 : 0.0
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.activeScratchpads

            delegate: Rectangle {
                id: badge
                required property var modelData
                readonly property bool isHovering: badgeMouse.containsMouse
                onIsHoveringChanged: root.hoveredCount = Math.max(0, root.hoveredCount + (isHovering ? 1 : -1))
                Component.onDestruction: {
                    if (isHovering) root.hoveredCount = Math.max(0, root.hoveredCount - 1);
                }

                width: 20
                height: 20
                radius: height / 2
                color: scratchBadgeLg.isLiquidActive
                    ? "transparent"
                    : (badge.modelData.isOpen
                        ? Theme.glassSurfaceActive
                        : (badgeMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"))
                border.width: 0
                border.color: "transparent"

                LiquidGlassSurface {
                    id: scratchBadgeLg
                    anchors.fill: parent
                    z: -1
                    cornerRadius: parent.height / 2
                    active: badge.modelData.isOpen
                    hovered: badgeMouse.containsMouse
                    onlyWhenHighlighted: true
                }

                scale: badgeMouse.pressed ? 0.88 : (badgeMouse.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 130 } }

                Text {
                    anchors.centerIn: parent
                    text: badge.modelData.icon
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    color: (badge.modelData.isOpen || badgeMouse.containsMouse) ? Theme.text : Theme.subtext
                }

                MouseArea {
                    id: badgeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached([ShellState.script("scratchpad.sh"), badge.modelData.name]);
                    }
                }
            }
        }
    }
}
