import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

Item {
    id: root

    property var targetScreen: null
    property bool ownsActivePanel: true
    implicitWidth: 26
    implicitHeight: 26
    readonly property bool isPillHighlighted: (!root.ownsActivePanel || !archIcon.handedOff) && mouseArea.containsMouse

    // Uniform frosted glass pill matching WeatherWidget & NotificationButton
    Rectangle {
        id: buttonOutline
        anchors.fill: parent
        radius: height / 2
        opacity: archIcon.handoffOpacity
        visible: opacity > 0.01
        color: launcherLg.isLiquidActive ? "transparent" : (root.isPillHighlighted ? Theme.glassSurfaceHover : "transparent")
        border.width: 0

        LiquidGlassSurface {
            id: launcherLg
            anchors.fill: parent
            z: -1
            cornerRadius: parent.height / 2
            hovered: root.isPillHighlighted
            onlyWhenHighlighted: true
        }

        Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
    }

    scale: (!root.ownsActivePanel || !archIcon.handedOff)
        ? (mouseArea.pressed ? 0.90 : (root.isPillHighlighted ? 1.05 : 1.0))
        : 1.0
    Behavior on scale { NumberAnimation { duration: ShellState.animDur(200, 140); easing.type: ShellState.animPrimaryEase } }

    Text {
        id: archIcon
        anchors.centerIn: parent
        text: "󰣇"
        font.family: Theme.iconFont
        font.pixelSize: 15
        color: (root.ownsActivePanel && ShellState.sysMenuOpen) ? Theme.accent : Theme.text
        layer.enabled: ShellState.liquidGlassEnabled
        layer.effect: DropShadow {
            verticalOffset: 1
            radius: 4
            samples: 9
            color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
        }

        // Seamless spatial handoff to SystemMenu's floatingArchLogo during Left Island morph
        readonly property bool handedOff: root.ownsActivePanel && (ShellState.sysMenuOpen || ShellState.leftIslandHeight > Theme.barHeight + 0.5)
        property real handoffOpacity: 1.0
        opacity: handoffOpacity

        Component.onCompleted: handoffOpacity = handedOff ? 0.0 : 1.0

        NumberAnimation {
            id: archHandoffOutAnim
            target: archIcon
            property: "handoffOpacity"
            to: 0.0
            duration: 36
            easing.type: Easing.Linear
        }

        onHandedOffChanged: {
            if (handedOff) {
                archHandoffOutAnim.restart();
            } else {
                archHandoffOutAnim.stop();
                handoffOpacity = 1.0;
            }
        }

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ShellState.activateMonitor(root.targetScreen);
            ShellState.toggleSysMenu();
        }
    }
}
