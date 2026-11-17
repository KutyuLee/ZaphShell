import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    required property var screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-brightness-dim"
    exclusiveZone: 0
    mask: Region {} // 100% click-through! Completely transparent to all user input

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: Math.max(0.0, Math.min(0.85, (1.0 - ShellState.brightness) * 0.85))
        visible: opacity > 0.005

        Behavior on opacity {
            NumberAnimation { duration: 60; easing.type: Easing.OutCubic }
        }
    }
}
