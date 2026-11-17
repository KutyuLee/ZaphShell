import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    anchors {
        top: true
    }

    margins {
        top: 0
    }

    implicitWidth: 500
    implicitHeight: Theme.barBottomY + 60
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-kb-osd"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    readonly property bool isKbMode: ShellState.centerIslandMode === "kbLayout"
    visible: osdContent.opacity > 0.005

    property string displayedLayout: ShellState.activeKeyboardLayout
    property string incomingLayout: ShellState.activeKeyboardLayout
    property real textSlideY: 0
    property real textOpacity: 1.0
    property real iconScale: 1.0
    property real pulseScale: 1.0
    property real badgeFlash: 0.0

    function playSwitchAnimation() {
        const nextName = ShellState.activeKeyboardLayout;
        if (!root.isKbMode) {
            root.displayedLayout = nextName;
            root.textSlideY = 0;
            root.textOpacity = 1.0;
        } else {
            root.incomingLayout = nextName;
            textSwapAnim.restart();
        }
        badgePulseAnim.restart();
    }

    Connections {
        target: ShellState
        function onKbSwitchSeqChanged() {
            root.playSwitchAnimation();
        }
        function onActiveKeyboardLayoutChanged() {
            if (!textSwapAnim.running && root.displayedLayout !== ShellState.activeKeyboardLayout) {
                root.playSwitchAnimation();
            }
        }
    }

    onIsKbModeChanged: {
        if (isKbMode && root.displayedLayout !== ShellState.activeKeyboardLayout) {
            root.playSwitchAnimation();
        }
    }

    SequentialAnimation {
        id: textSwapAnim
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "textSlideY"
                to: -10
                duration: ShellState.animDur(120, 85)
                easing.type: ShellState.isSnappyAnimations ? Easing.InCubic : Easing.InOutCubic
            }
            NumberAnimation {
                target: root
                property: "textOpacity"
                to: 0.0
                duration: ShellState.animDur(120, 85)
                easing.type: ShellState.isSnappyAnimations ? Easing.InCubic : Easing.InOutCubic
            }
        }
        ScriptAction {
            script: {
                root.displayedLayout = ShellState.activeKeyboardLayout;
                root.textSlideY = 12;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "textSlideY"
                to: 0
                duration: ShellState.animDur(260, 200)
                easing.type: ShellState.animPrimaryEase
            }
            NumberAnimation {
                target: root
                property: "textOpacity"
                to: 1.0
                duration: ShellState.animDur(240, 180)
                easing.type: ShellState.animPrimaryEase
            }
        }
    }

    ParallelAnimation {
        id: badgePulseAnim
        SequentialAnimation {
            NumberAnimation { target: root; property: "iconScale"; to: ShellState.isSnappyAnimations ? 1.24 : 1.18; duration: ShellState.animDur(150, 110); easing.type: ShellState.animPrimaryEase }
            NumberAnimation { target: root; property: "iconScale"; to: 1.0; duration: ShellState.animDur(240, 180); easing.type: ShellState.isSnappyAnimations ? Easing.OutBack : Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "pulseScale"; to: ShellState.isSnappyAnimations ? 1.045 : 1.032; duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase }
            NumberAnimation { target: root; property: "pulseScale"; to: 1.0; duration: ShellState.animDur(260, 200); easing.type: ShellState.isSnappyAnimations ? Easing.OutCubic : Easing.InOutSine }
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "badgeFlash"; to: 1.0; duration: ShellState.animDur(130, 90); easing.type: ShellState.animPrimaryEase }
            NumberAnimation { target: root; property: "badgeFlash"; to: 0.0; duration: ShellState.animDur(380, 300); easing.type: ShellState.isSnappyAnimations ? Easing.OutCubic : Easing.InOutSine }
        }
    }

    Item {
        id: osdContent
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTopGap
        width: ShellState.centerIslandWidth
        height: ShellState.centerIslandHeight
        clip: true
        opacity: root.isKbMode ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: ShellState.animDur(260, 180); easing.type: Easing.InOutCubic }
        }

        Item {
            id: kbDeformBox
            width: ShellState.targetKbIslandWidth
            height: ShellState.targetKbIslandHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0

            transform: Scale {
                origin.x: kbDeformBox.width / 2
                origin.y: 0
                xScale: ShellState.centerIslandWidth / Math.max(1, kbDeformBox.width)
                yScale: ShellState.centerIslandHeight / Math.max(1, kbDeformBox.height)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 14
                    color: Qt.tint(Theme.glassCard, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24 * root.badgeFlash))
                    border.width: 1
                    border.color: Qt.rgba(
                        Theme.glassBorder.r + (Theme.accent.r - Theme.glassBorder.r) * root.badgeFlash,
                        Theme.glassBorder.g + (Theme.accent.g - Theme.glassBorder.g) * root.badgeFlash,
                        Theme.glassBorder.b + (Theme.accent.b - Theme.glassBorder.b) * root.badgeFlash,
                        Math.max(Theme.glassBorder.a, 0.55 * root.badgeFlash)
                    )
                    scale: root.iconScale

                    Text {
                        anchors.centerIn: parent
                        text: "󰌌"
                        font.family: Theme.iconFont
                        font.pixelSize: 19
                        color: Theme.accent
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "Keyboard Layout"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: "SUPER + Space to switch"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.textDim
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.maximumWidth: 215
                    implicitWidth: Math.min(215, Math.max(88, layoutNameTxt.implicitWidth + 24))
                    radius: 14
                    clip: true
                    scale: 1.0 + (root.pulseScale - 1.0) * 0.7
                    color: Qt.tint(Theme.glassSurfaceActive, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22 * root.badgeFlash))
                    border.width: 1
                    border.color: root.badgeFlash > 0.05
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35 + 0.45 * root.badgeFlash)
                        : Theme.glassBorder

                    Behavior on implicitWidth {
                        NumberAnimation { duration: ShellState.animDur(300, 220); easing.type: ShellState.animPrimaryEase }
                    }

                    Text {
                        id: layoutNameTxt
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, parent.width - 16)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        y: (parent.height - height) / 2 + root.textSlideY
                        opacity: root.textOpacity
                        text: root.displayedLayout
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.text
                    }
                }
            }
        }
    }
}
