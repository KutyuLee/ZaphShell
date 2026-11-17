import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: root

    // Centered at the top — morphs directly inside the Center Dynamic Island
    anchors {
        top: true
    }

    margins {
        top: 0
    }

    implicitWidth: ShellState.targetPowerIslandWidth + 48
    implicitHeight: Theme.barBottomY + ShellState.targetPowerIslandHeight + 32
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-power-osd"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    readonly property bool isPowerMode: ShellState.centerIslandMode === "power"
    visible: osdContent.opacity > 0.005

    WlrLayershell.keyboardFocus: ShellState.powerOsdOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: ShellState.powerOsdOpen
        windows: [root]
        onCleared: {
            ShellState.powerOsdOpen = false;
        }
    }

    property int selectedIndex: 0

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
        }
    }

    // Minimalist Monochrome Session Actions inside the Center Dynamic Island
    readonly property var powerActions: [
        {
            id: "lock",
            icon: "󰌾",
            label: "Lock",
            danger: false,
            action: function() {
                ShellState.powerOsdOpen = false;
                ShellState.lockScreen();
            }
        },
        {
            id: "suspend",
            icon: "󰒲",
            label: "Sleep",
            danger: false,
            action: function() {
                ShellState.powerOsdOpen = false;
                Quickshell.execDetached(["systemctl", "suspend"]);
            }
        },
        {
            id: "reboot",
            icon: "󰑓",
            label: "Restart",
            danger: false,
            action: function() {
                ShellState.powerOsdOpen = false;
                Quickshell.execDetached(["systemctl", "reboot"]);
            }
        },
        {
            id: "poweroff",
            icon: "󰐥",
            label: "Power Off",
            danger: true,
            action: function() {
                ShellState.powerOsdOpen = false;
                Quickshell.execDetached(["systemctl", "poweroff"]);
            }
        },
        {
            id: "logout",
            icon: "󰍃",
            label: "Log Out",
            danger: false,
            action: function() {
                ShellState.powerOsdOpen = false;
                ShellState.dispatchHypr("hl.dsp.exit()", "exit");
            }
        }
    ]

    DesktopCaptureSource {
        id: powerCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    // Clipped directly to the Center Dynamic Island pill bounds painted by ScreenFrame.qml
    Item {
        id: osdContent
        readonly property bool liquidGlassHost: true
        readonly property var liquidSource: powerCap.textureSource
        readonly property bool liquidSourceReady: powerCap.ready
        readonly property real liquidOriginX: (ShellState.mainScreenWidth - root.width) / 2
        readonly property real liquidOriginY: 0
        readonly property int liquidLayoutRev: Math.round(ShellState.centerIslandWidth + ShellState.centerIslandHeight * 3 + root.selectedIndex * 7)

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTopGap
        width: ShellState.centerIslandWidth
        height: ShellState.centerIslandHeight
        clip: true
        opacity: root.isPowerMode ? 1.0 : 0.0
        focus: ShellState.powerOsdOpen

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
        }

        Item {
            id: powerDeformBox
            width: ShellState.targetPowerIslandWidth
            height: ShellState.targetPowerIslandHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0

            transform: Scale {
                origin.x: powerDeformBox.width / 2
                origin.y: 0
                xScale: ShellState.centerIslandWidth / Math.max(1, powerDeformBox.width)
                yScale: ShellState.centerIslandHeight / Math.max(1, powerDeformBox.height)
            }

        Keys.onEscapePressed: {
            ShellState.powerOsdOpen = false;
        }
        Keys.onRightPressed: {
            root.selectedIndex = (root.selectedIndex + 1) % root.powerActions.length;
        }
        Keys.onDownPressed: {
            root.selectedIndex = (root.selectedIndex + 1) % root.powerActions.length;
        }
        Keys.onLeftPressed: {
            root.selectedIndex = (root.selectedIndex - 1 + root.powerActions.length) % root.powerActions.length;
        }
        Keys.onUpPressed: {
            root.selectedIndex = (root.selectedIndex - 1 + root.powerActions.length) % root.powerActions.length;
        }
        Keys.onReturnPressed: {
            if (root.selectedIndex >= 0 && root.selectedIndex < root.powerActions.length) {
                root.powerActions[root.selectedIndex].action();
            }
        }

        RowLayout {
            anchors.centerIn: parent
            width: ShellState.targetPowerIslandWidth - 44
            height: ShellState.targetPowerIslandHeight - 24
            spacing: 10

            Repeater {
                model: root.powerActions

                delegate: Item {
                    id: btn
                    required property int index
                    required property var modelData

                    readonly property bool isSelected: root.selectedIndex === btn.index
                    readonly property bool isHovered: btnMouse.containsMouse || btn.isSelected

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 46
                            height: 46
                            radius: 23
                            color: (powerBtnLg.isLiquidActive && !(btn.isHovered && btn.modelData.danger))
                                ? "transparent"
                                : (btn.isHovered
                                    ? (btn.modelData.danger ? Theme.red : Theme.sliderFill)
                                    : Theme.glassCard)
                            border.width: (powerBtnLg.isLiquidActive || btn.isHovered) ? 0 : 1
                            border.color: btn.isHovered
                                ? "transparent"
                                : Theme.glassBorder

                            LiquidGlassSurface {
                                id: powerBtnLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 23
                                visible: !(btn.isHovered && btn.modelData.danger)
                                active: btn.isHovered && !btn.modelData.danger
                            }

                            scale: btnMouse.pressed ? 0.90 : (btn.isHovered ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: btn.modelData.icon
                                font.family: Theme.iconFont
                                font.pixelSize: 19
                                color: btn.isHovered
                                    ? (btn.modelData.danger ? "#FFFFFF" : (powerBtnLg.isLiquidActive ? Theme.text : Theme.sliderFillFg))
                                    : Theme.text
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: btn.isHovered ? Font.Bold : Font.Medium
                            color: btn.isHovered ? Theme.text : Theme.subtext
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = btn.index
                        onClicked: btn.modelData.action()
                    }
                }
            }
        }
        }
    }
}
