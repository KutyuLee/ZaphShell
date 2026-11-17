import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
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

    implicitWidth: ShellState.targetVolumeIslandWidth + 48
    implicitHeight: Theme.barBottomY + 40
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-volume-osd"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    readonly property bool isVolumeMode: ShellState.centerIslandMode === "volume"
    visible: osdContent.opacity > 0.005

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool isMuted: audio ? audio.muted : false
    readonly property real vol: (audio && !isNaN(audio.volume)) ? Math.min(1.0, Math.max(0.0, audio.volume)) : 0.0

    function getVolumeIcon() {
        if (isMuted || vol === 0) return "󰝟";
        if (vol < 0.33) return "󰕿";
        if (vol < 0.66) return "󰖀";
        return "󰕾";
    }

    // Clipped directly to the Center Dynamic Island pill bounds painted by ScreenFrame.qml
    // Smoothly fades in/out while stretching and deforming with the capsule!
    Item {
        id: osdContent
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTopGap
        width: ShellState.centerIslandWidth
        height: ShellState.centerIslandHeight
        clip: true
        opacity: root.isVolumeMode ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: ShellState.animDur(270, 200); easing.type: Easing.InOutCubic }
        }

        HoverHandler {
            id: osdHover
            onHoveredChanged: {
                if (hovered) {
                    ShellState.pauseVolumeOsdTimer();
                } else {
                    ShellState.resumeVolumeOsdTimer();
                }
            }
        }

        Item {
            id: volDeformBox
            width: ShellState.targetVolumeIslandWidth
            height: ShellState.targetVolumeIslandHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0

            transform: Scale {
                origin.x: volDeformBox.width / 2
                origin.y: 0
                xScale: ShellState.centerIslandWidth / Math.max(1, volDeformBox.width)
                yScale: ShellState.centerIslandHeight / Math.max(1, volDeformBox.height)
            }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 14
            spacing: 10

            // 1. Volume / Mute Icon Button
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: muteMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                scale: muteMouse.pressed ? 0.90 : 1.0

                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: root.getVolumeIcon()
                    font.family: Theme.iconFont
                    font.pixelSize: 17
                    color: root.isMuted ? Theme.red : Theme.text
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ShellState.triggerVolumeOsd();
                        if (root.audio) {
                            root.audio.muted = !root.audio.muted;
                        }
                    }
                }
            }

            // 2. Classic Thick Monochrome Capsule Slider (physically stretches with the Dynamic Island pill)
            Rectangle {
                id: sliderTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                radius: 10
                color: Theme.sliderTrack
                border.color: Theme.glassBorder
                border.width: 1
                clip: true

                Rectangle {
                    id: volOsdFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(parent.height, parent.height + (parent.width - parent.height) * (root.isMuted ? 0 : root.vol))
                    radius: 10
                    color: root.isMuted ? Theme.redContainer : Theme.sliderFill
                    border.color: root.isMuted ? Theme.red : Theme.glassHighlight
                    border.width: 1

                    Behavior on width {
                        NumberAnimation { duration: ShellState.animDur(130, 75); easing.type: ShellState.animPrimaryEase }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    function setVolFromX(mx) {
                        if (root.audio) {
                            ShellState.triggerVolumeOsd();
                            const usable = Math.max(1, sliderTrack.width - 20);
                            const normalized = (mx - 10) / usable;
                            root.audio.volume = Math.max(0.0, Math.min(1.0, normalized));
                            if (root.audio.muted && normalized > 0.01) {
                                root.audio.muted = false;
                            }
                        }
                    }

                    onWheel: wheel => {
                        ShellState.triggerVolumeOsd();
                        if (root.audio) {
                            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            root.audio.volume = Math.max(0.0, Math.min(1.0, root.vol + delta));
                        }
                    }

                    onPressed: mouse => setVolFromX(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed) setVolFromX(mouse.x);
                    }
                }
            }

            // 3. Tabular Volume Percentage
            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: root.isMuted ? "Mute" : (Math.round(root.vol * 100) + "%")
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
                color: root.isMuted ? Theme.red : Theme.text
            }
        }
        }
    }
}
