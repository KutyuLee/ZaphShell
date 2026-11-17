import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."

PanelWindow {
    id: root

    // Centered on the top edge — blooms directly inside the Center Dynamic Island
    anchors {
        top: true
    }

    margins {
        top: 0
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    readonly property bool isNotifMode: ShellState.centerIslandMode === "notif"
    readonly property real singleCardHeight: Theme.notifCardHeight

    implicitWidth: Theme.notifCardWidth + 48
    implicitHeight: Theme.barBottomY + Theme.notifCardHeight * 2 + 48

    mask: Region { item: notifContent }

    visible: notifContent.opacity > 0.005

    // Clipped to the exact Center Dynamic Island bounds painted by ScreenFrame.qml
    Item {
        id: notifContent
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barTopGap
        width: ShellState.centerIslandWidth
        height: ShellState.centerIslandHeight
        clip: true
        opacity: root.isNotifMode ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.InOutCubic }
        }

        transform: Scale {
            origin.x: notifContent.width / 2
            origin.y: 0
            xScale: 1.0
            yScale: ShellState.islandDeformScaleY
        }

        ListView {
            id: notifList
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            spacing: 0
            model: ShellState.activeNotifsModel
            interactive: false
            clip: true

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: ShellState.animDur(260, 180); easing.type: ShellState.animPrimaryEase }
            }

            displaced: Transition {
                NumberAnimation { property: "y"; duration: ShellState.animDur(300, 220); easing.type: ShellState.animPrimaryEase }
            }

            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: ShellState.animDur(240, 160); easing.type: ShellState.animPrimaryEase }
            }

            delegate: Item {
                id: notifCard
                required property var model
                required property int index

                width: notifList.width
                height: root.singleCardHeight - 2

                property bool hoveredOnce: false

                Timer {
                    id: autoDismissTimer
                    interval: ShellState.notifTimeoutSec * 1000
                    running: true
                    repeat: false
                    onTriggered: {
                        ShellState.dismissActiveNotif(notifCard.index);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 12

                    // App / Notification Thumbnail
                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 12
                        color: Theme.glassCard
                        clip: true

                        Image {
                            id: imgView
                            anchors.fill: parent
                            visible: notifCard.model.isFileImg && notifCard.model.iconSrc.length > 0
                            source: notifCard.model.isFileImg ? notifCard.model.iconSrc : ""
                            fillMode: Image.PreserveAspectCrop
                        }

                        IconImage {
                            id: iconView
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            visible: !notifCard.model.isFileImg && notifCard.model.iconSrc.length > 0
                            source: (!notifCard.model.isFileImg && notifCard.model.iconSrc.length > 0) ? Quickshell.iconPath(notifCard.model.iconSrc) : ""
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !imgView.visible && (!iconView.visible || iconView.status !== Image.Ready)
                            text: "󰂚"
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: Theme.subtext
                        }
                    }

                    // Content Details
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: notifCard.model.appName.length > 0 ? notifCard.model.appName : "Notification"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeTiny
                                font.weight: Font.DemiBold
                                color: Theme.subtext
                            }

                            Text {
                                text: notifCard.model.time
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }

                            Item { Layout.fillWidth: true }

                            // Close Button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: closeArea.containsMouse ? Theme.glassSurfaceHover : "transparent"
                                scale: closeArea.pressed ? 0.88 : (closeArea.containsMouse ? 1.08 : 1.0)

                                Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: closeArea.containsMouse ? Theme.text : Theme.subtext
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ShellState.dismissActiveNotif(notifCard.index);
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: notifCard.model.summary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: Font.Bold
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: notifCard.model.body.length > 0
                            text: notifCard.model.body
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.subtext
                            wrapMode: Text.Wrap
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }
                }

                // Subtle inset separator line when 2 notifications are displayed simultaneously
                Rectangle {
                    visible: notifCard.index === 0 && ShellState.activeNotifsModel.count > 1
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    height: 1
                    color: Theme.glassBorder
                }

                // Interactive click-to-activate and hover-to-dismiss handler
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    hoverEnabled: true

                    onEntered: {
                        notifCard.hoveredOnce = true;
                        autoDismissTimer.stop();
                    }

                    onExited: {
                        if (notifCard.hoveredOnce) {
                            ShellState.dismissActiveNotif(notifCard.index);
                        }
                    }

                    onClicked: {
                        ShellState.activateNotification(notifCard.index);
                    }
                }
            }
        }
    }
}
