import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: root

    anchors {
        left: true
        top: true
        bottom: true
    }

    margins {
        left: 0
        top: 0
        bottom: 0
    }

    property var barWindow: null
    readonly property real w: Math.max(0, ShellState.weatherDebugWidth)
    readonly property real h: Math.max(0, ShellState.weatherDebugHeight)
    readonly property real targetW: ShellState.weatherDebugTargetWidth
    readonly property real targetH: ShellState.weatherDebugTargetHeight
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, ShellState.smoothWeatherDebugHeight / Math.max(1, targetH)))

    implicitWidth: 640
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-weather-debug"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: ShellState.weatherDebugOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: h > 0.5 || ShellState.weatherDebugOpen

    Item {
        id: cardMask
        x: debugCard.x
        y: debugCard.y
        width: (ShellState.weatherDebugOpen || root.h > 0.5) ? debugCard.width : 0
        height: (ShellState.weatherDebugOpen || root.h > 0.5) ? debugCard.height : 0
    }

    mask: Region { item: cardMask }

    Item {
        focus: ShellState.weatherDebugOpen
        Keys.onEscapePressed: ShellState.weatherDebugOpen = false
    }

    readonly property var weatherStates: [
        { mode: "",             icon: "󰑐", label: "Live Weather (Auto)", accent: "#60A5FA" },
        { mode: "clear",        icon: "󰖙", label: "Clear Sky",           accent: "#FBBF24" },
        { mode: "partlyCloudy", icon: "󰖕", label: "Partly Cloudy",       accent: "#FCD34D" },
        { mode: "cloudy",       icon: "󰖐", label: "Cloudy / Overcast",   accent: "#94A3B8" },
        { mode: "rain",         icon: "󰖗", label: "Rainy",               accent: "#38BDF8" },
        { mode: "storm",        icon: "󰖓", label: "Thunderstorm",        accent: "#FACC15" },
        { mode: "snow",         icon: "󰖘", label: "Snowy",               accent: "#BAE6FD" },
        { mode: "fog",          icon: "󰖑", label: "Foggy",               accent: "#99F6E4" }
    ]

    DesktopCaptureSource {
        id: dbgCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    Rectangle {
        id: debugCard
        readonly property real minCenterX: Theme.barMarginX + root.targetW / 2
        readonly property real clampedCenterX: Math.max(minCenterX, ShellState.weatherDebugCenterX)
        readonly property bool useLiquid: ShellState.liquidGlassEnabled && dbgCap.ready

        x: clampedCenterX - width / 2
        y: Theme.barBottomY + 4
        width: Math.max(1, root.w)
        height: Math.max(1, root.h)
        radius: Math.min(width / 2, height / 2, 22)
        color: "transparent"
        border.width: 0

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !debugCard.useLiquid
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.islandTopColor }
                GradientStop { position: 0.62; color: Theme.islandMidColor }
                GradientStop { position: 1.0; color: Theme.islandBottomColor }
            }
            border.width: 1
            border.color: Theme.borderStroke
        }

        LiquidGlassEffect {
            anchors.fill: parent
            visible: debugCard.useLiquid
            desktopSource: dbgCap.textureSource
            screenX: debugCard.x
            screenY: debugCard.y
            screenW: debugCard.width
            screenH: debugCard.height
            cornerRadius: debugCard.radius
            bevelWidth: 0.16
        }

        Item {
            readonly property bool liquidGlassHost: true
            readonly property var liquidSource: dbgCap.textureSource
            readonly property bool liquidSourceReady: dbgCap.ready
            readonly property real liquidOriginX: 0
            readonly property real liquidOriginY: 0
            readonly property int liquidLayoutRev: Math.round(root.w + root.h * 3)
            anchors.fill: parent
            clip: true

            Item {
                width: root.targetW
                height: root.targetH
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter

                transform: Scale {
                    origin.x: root.targetW / 2
                    origin.y: 0
                    xScale: root.w / Math.max(1, root.targetW)
                    yScale: (0.72 + 0.28 * root.smoothHRatio) * ShellState.weatherDebugDeformScaleY
                }

                Column {
                    x: 8
                    y: 8
                    width: root.targetW - 16
                    spacing: 2

                    // Header row
                    Item {
                        width: parent.width
                        height: 22

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6

                            Text {
                                text: "DEBUG MENU"
                                font.family: Theme.fontFamily
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                color: Theme.textDim
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: closeMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                                scale: closeMouse.pressed ? 0.88 : (closeMouse.containsMouse ? 1.08 : 1.0)
                                Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                                Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 11
                                    color: closeMouse.containsMouse ? Theme.text : Theme.textDim
                                    Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.weatherDebugOpen = false
                                }
                            }
                        }
                    }

                    // Test Notification action row
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 8
                        color: testRowLg.isLiquidActive ? "transparent" : (testNotifRowMouse.pressed
                            ? Theme.glassSurfaceActive
                            : (testNotifRowMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"))

                        LiquidGlassSurface {
                            id: testRowLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: 8
                            onlyWhenHighlighted: true
                            hovered: testNotifRowMouse.containsMouse
                        }
                        scale: testNotifRowMouse.pressed ? 0.96 : (testNotifRowMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 110 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: "󰂞"
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                                color: Theme.accent
                            }

                            Text {
                                text: "Test Notification"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.subtext
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: testNotifRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ShellState.triggerTestNotification();
                                ShellState.weatherDebugOpen = false;
                            }
                        }
                    }

                    // Subtle divider between actions and weather preview states
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.glassBorder
                    }

                    // Day / Night / Auto sky override row
                    RowLayout {
                        width: parent.width
                        height: 28
                        spacing: 4

                        Repeater {
                            model: [
                                { key: "",      label: "Auto" },
                                { key: "day",   label: "󰖙 Day" },
                                { key: "night", label: "󰖔 Night" }
                            ]

                            delegate: Rectangle {
                                id: timePill
                                required property var modelData
                                readonly property bool isSel: ShellState.weatherDebugTime === modelData.key
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 8
                                color: timePillLg.isLiquidActive ? "transparent" : (timePill.isSel
                                    ? Theme.glassSurfaceActive
                                    : (timePillMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"))
                                border.width: (!timePillLg.isLiquidActive && timePill.isSel) ? 1 : 0
                                border.color: timePill.isSel ? Theme.glassBorder : "transparent"
                                scale: timePillMouse.pressed ? 0.94 : (timePillMouse.containsMouse ? 1.03 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 110 } }

                                LiquidGlassSurface {
                                    id: timePillLg
                                    anchors.fill: parent
                                    z: -1
                                    cornerRadius: 8
                                    onlyWhenHighlighted: true
                                    active: timePill.isSel
                                    hovered: timePillMouse.containsMouse
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: timePill.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.weight: timePill.isSel ? Font.DemiBold : Font.Medium
                                    color: timePill.isSel ? Theme.text : Theme.textDim
                                }

                                MouseArea {
                                    id: timePillMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ShellState.weatherDebugTime = timePill.modelData.key;
                                        ShellState.weatherOpen = true;
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.weatherStates

                        delegate: Rectangle {
                            id: stateItem
                            required property var modelData
                            readonly property bool isSelected: ShellState.weatherDebugMode === modelData.mode

                            width: parent.width
                            height: 28
                            radius: 8
                            color: stateItemLg.isLiquidActive ? "transparent" : (stateItem.isSelected
                                ? Theme.glassSurfaceActive
                                : (stateMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"))
                            border.width: (!stateItemLg.isLiquidActive && stateItem.isSelected) ? 1 : 0
                            border.color: stateItem.isSelected ? Theme.glassBorder : "transparent"

                            LiquidGlassSurface {
                                id: stateItemLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 8
                                onlyWhenHighlighted: true
                                active: stateItem.isSelected
                                hovered: stateMouse.containsMouse
                            }

                            scale: stateMouse.pressed ? 0.96 : (stateMouse.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 110 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: stateItem.modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: stateItem.modelData.accent
                                }

                                Text {
                                    text: stateItem.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: stateItem.isSelected ? Font.Bold : Font.Medium
                                    color: stateItem.isSelected ? Theme.text : Theme.subtext
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: stateItem.isSelected
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: stateItem.modelData.accent
                                }
                            }

                            MouseArea {
                                id: stateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.setWeatherDebugMode(stateItem.modelData.mode);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
