import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Rectangle {
    id: root

    property var targetScreen: null
    property bool ownsActivePanel: true
    readonly property int notifCount: ShellState.notifServer && ShellState.notifServer.trackedNotifications ? ShellState.notifServer.trackedNotifications.values.length : 0
    readonly property bool isPillHighlighted: (root.ownsActivePanel && ShellState.notifCenterOpen) || mouseArea.containsMouse

    implicitWidth: 24
    implicitHeight: 24
    radius: height / 2
    color: notifBtnLg.isLiquidActive
        ? "transparent"
        : ((root.ownsActivePanel && ShellState.notifCenterOpen)
            ? Theme.glassSurfaceActive
            : (mouseArea.containsMouse ? Theme.glassSurfaceHover : "transparent"))
    border.width: 0

    LiquidGlassSurface {
        id: notifBtnLg
        anchors.fill: parent
        z: -1
        cornerRadius: parent.height / 2
        active: root.ownsActivePanel && ShellState.notifCenterOpen
        hovered: mouseArea.containsMouse
        onlyWhenHighlighted: true
    }
    scale: mouseArea.pressed ? 0.90 : (mouseArea.containsMouse ? 1.06 : 1.0)

    Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 115); easing.type: ShellState.animPrimaryEase } }
    Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 130) } }

    Connections {
        target: ShellState
        function onDndActiveChanged() {
            bellAnim.restart();
        }
    }

    SequentialAnimation {
        id: bellAnim
        ParallelAnimation {
            NumberAnimation { target: bellIcon; property: "scale"; to: 1.22; duration: ShellState.animDur(120, 80); easing.type: Easing.OutCubic }
            NumberAnimation { target: bellIcon; property: "rotation"; to: -16; duration: ShellState.animDur(100, 70); easing.type: Easing.OutCubic }
        }
        NumberAnimation { target: bellIcon; property: "rotation"; to: 12; duration: ShellState.animDur(110, 75); easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: bellIcon; property: "rotation"; to: 0; duration: ShellState.animDur(140, 95); easing.type: ShellState.animPrimaryEase }
            NumberAnimation { target: bellIcon; property: "scale"; to: 1.0; duration: ShellState.animDur(140, 95); easing.type: ShellState.animPrimaryEase }
        }
    }

    Text {
        id: bellIcon
        anchors.centerIn: parent
        text: ShellState.dndActive ? "󰂛" : (root.notifCount > 0 ? "󰂚" : "󰂜")
        font.family: Theme.iconFont
        font.pixelSize: 13
        color: (root.ownsActivePanel && ShellState.notifCenterOpen) ? Theme.accent : (ShellState.dndActive ? Theme.textDim : Theme.text)
        Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 140) } }
        layer.enabled: ShellState.liquidGlassEnabled
        layer.effect: DropShadow {
            verticalOffset: 1
            radius: 4
            samples: 9
            color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
        }
    }

    // Unread indicator dot
    Rectangle {
        visible: root.notifCount > 0 && !ShellState.dndActive
        width: 6
        height: 6
        radius: 3
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
        color: Theme.accent
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            ShellState.activateMonitor(root.targetScreen);
            ShellState.toggleNotifCenter();
        }
    }
}
