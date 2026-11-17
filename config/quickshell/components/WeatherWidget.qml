import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".."

Rectangle {
    id: root

    property var targetScreen: null
    property bool ownsActivePanel: true
    property var skySource: null
    property real skyOriginX: 0
    property real skyOriginY: 0
    readonly property bool isPillHighlighted: (root.ownsActivePanel && ShellState.weatherOpen) || weatherMouse.containsMouse

    implicitHeight: 24
    implicitWidth: weatherRow.implicitWidth + 14
    radius: height / 2

    color: weatherBtnLg.isLiquidActive
        ? "transparent"
        : ((root.ownsActivePanel && ShellState.weatherOpen)
            ? Theme.glassSurfaceActive
            : (weatherMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"))
    border.width: 0

    LiquidGlassSurface {
        id: weatherBtnLg
        anchors.fill: parent
        z: -2
        cornerRadius: parent.height / 2
        active: root.ownsActivePanel && ShellState.weatherOpen
        hovered: weatherMouse.containsMouse
        onlyWhenHighlighted: true
        activeTint: (root.ownsActivePanel && ShellState.weatherOpen && !Theme.lightMode)
            ? Qt.rgba(0.92, 0.96, 1.0, 0.14)
            : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.34) : Qt.rgba(0.28, 0.34, 0.46, 0.24))
    }

    Item {
        id: skyGlassHost
        anchors.fill: parent
        z: -1
        visible: root.ownsActivePanel && root.skySource !== null && ShellState.weatherSkyProgress > 0.005
        opacity: ShellState.weatherSkyProgress

        readonly property bool liquidGlassHost: true
        readonly property var liquidSource: root.skySource
        readonly property bool liquidSourceReady: root.skySource !== null
        readonly property real liquidOriginX: root.skyOriginX
        readonly property real liquidOriginY: root.skyOriginY
        readonly property real liquidTexWidth: Math.max(1, ShellState.rightIslandWidth)
        readonly property real liquidTexHeight: Math.max(1, ShellState.rightIslandHeight)
        readonly property real liquidLayoutRev: ShellState.rightIslandWidth + ShellState.rightIslandHeight * 3.0

        LiquidGlassSurface {
            id: weatherBtnSkyLg
            anchors.fill: parent
            cornerRadius: parent.height / 2
            active: root.ownsActivePanel && (ShellState.weatherOpen || ShellState.weatherSkyProgress > 0.005)
            hovered: weatherMouse.containsMouse
            onlyWhenHighlighted: true
            activeTint: !Theme.lightMode
                ? Qt.rgba(0.92, 0.96, 1.0, 0.14)
                : Qt.rgba(1.0, 1.0, 1.0, 0.34)
        }
    }

    scale: weatherMouse.pressed ? 0.94 : (weatherMouse.containsMouse ? 1.03 : 1.0)
    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on border.color { ColorAnimation { duration: 140 } }

    RowLayout {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 6
        layer.enabled: ShellState.liquidGlassEnabled
        layer.effect: DropShadow {
            verticalOffset: 1
            radius: 4
            samples: 9
            color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
        }

        Text {
            text: ShellState.weatherIcon || "󰖐"
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: Theme.text
        }

        Text {
            text: ShellState.weatherTemp || "--°C"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.text
        }
    }

    MouseArea {
        id: weatherMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ShellState.activateMonitor(root.targetScreen);
            ShellState.toggleWeather();
        }
    }
}
