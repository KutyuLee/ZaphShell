import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "../.."

ColumnLayout {
    id: alertsTab
    required property int activeTab
    property var desktopSource: null
    property bool desktopSourceReady: true
    readonly property bool liquidActive: ShellState.liquidGlassEnabled && alertsTab.desktopSource !== null && alertsTab.desktopSourceReady
    property real screenWidth: ShellState.mainScreenWidth
    property real screenHeight: ShellState.mainScreenHeight
    property real panelScaleX: 1.0
    property real panelScaleY: 1.0
    property real liquidCardBaseX: 0
    property real liquidCardBaseY: Theme.barBottomY + 54
    anchors.fill: parent
    spacing: 10
    opacity: alertsTab.activeTab === 2 ? 1.0 : 0.0
    visible: opacity > 0.01
    enabled: alertsTab.activeTab === 2
    transform: Translate {
        x: alertsTab.activeTab === 2 ? 0 : 16
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: 180 } }

    component LiquidGlassLens: ShaderEffect {
        required property real lensScreenX
        required property real lensScreenY
        required property real lensScreenW
        required property real lensScreenH
        required property real cornerRadius
        property color tintColor: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(0.16, 0.19, 0.26, 0.08)
        property color rimColor: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.72)
        property real bevelWidth: 0.15
        property real frost: 0.60

        visible: alertsTab.liquidActive
        property var uSource: alertsTab.desktopSource
        property vector4d uBounds: Qt.vector4d(
            lensScreenX / Math.max(1, alertsTab.screenWidth),
            lensScreenY / Math.max(1, alertsTab.screenHeight),
            lensScreenW / Math.max(1, alertsTab.screenWidth),
            lensScreenH / Math.max(1, alertsTab.screenHeight)
        )
        property color uTint: tintColor
        property color uRimColor: rimColor
        property size uBoxSize: Qt.size(Math.max(1, width), Math.max(1, height))
        property size uTexSize: Qt.size(Math.max(1, alertsTab.screenWidth), Math.max(1, alertsTab.screenHeight))
        property real uRadius: cornerRadius
        property real uRefraction: 4.2
        property real uBevelDepth: 4.8
        property real uBevelWidth: bevelWidth
        property real uAberration: 0.08
        property real uFrost: frost
        fragmentShader: Qt.resolvedUrl("../liquid_glass.frag.qsb")
    }

    // Header Row: Title + Minimal DND & Clear All Glass Buttons
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        spacing: 8

        Text {
            text: "Notifications"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.text
            layer.enabled: ShellState.liquidGlassEnabled
            layer.effect: DropShadow {
                verticalOffset: 1
                radius: 5
                samples: 11
                color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.25 : 0.78)
            }
        }

        Item { Layout.fillWidth: true }

        // Minimal DND Toggle Button
        GlassBox {
            id: dndBtn
            autoLiquidGlass: false
            implicitWidth: 32
            implicitHeight: 32
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            cornerRadius: 16
            active: ShellState.dndActive
            hovered: dndMouse.containsMouse
            pressed: dndMouse.pressed
            color: alertsTab.liquidActive ? "transparent" : (ShellState.dndActive ? Theme.glassSurfaceActive : (dndMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard))
            border.width: alertsTab.liquidActive ? 0 : 1

            LiquidGlassLens {
                anchors.fill: parent
                z: 0
                lensScreenX: alertsTab.liquidCardBaseX + dndBtn.x * alertsTab.panelScaleX
                lensScreenY: alertsTab.liquidCardBaseY - 42 * alertsTab.panelScaleY + dndBtn.y * alertsTab.panelScaleY
                lensScreenW: dndBtn.width * alertsTab.panelScaleX
                lensScreenH: dndBtn.height * alertsTab.panelScaleY
                cornerRadius: dndBtn.cornerRadius
                bevelWidth: 0.24
                tintColor: dndBtn.active
                    ? (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.34) : Qt.rgba(0.28, 0.34, 0.46, 0.24))
                    : (dndMouse.containsMouse ? (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.24) : Qt.rgba(0.22, 0.26, 0.34, 0.14))
                                              : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(0.16, 0.19, 0.26, 0.08)))
                rimColor: dndBtn.active || dndMouse.containsMouse
                    ? Qt.rgba(1.0, 1.0, 1.0, 0.90)
                    : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.72))
            }

            Connections {
                target: ShellState
                function onDndActiveChanged() {
                    if (alertsTab.visible) alertsDndAnim.restart();
                }
            }

            SequentialAnimation {
                id: alertsDndAnim
                ParallelAnimation {
                    NumberAnimation { target: alertsDndIcon; property: "scale"; to: 1.24; duration: ShellState.animDur(120, 80); easing.type: Easing.OutCubic }
                    NumberAnimation { target: alertsDndIcon; property: "rotation"; to: -18; duration: ShellState.animDur(100, 70); easing.type: Easing.OutCubic }
                }
                NumberAnimation { target: alertsDndIcon; property: "rotation"; to: 14; duration: ShellState.animDur(110, 75); easing.type: Easing.InOutCubic }
                ParallelAnimation {
                    NumberAnimation { target: alertsDndIcon; property: "rotation"; to: 0; duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase }
                    NumberAnimation { target: alertsDndIcon; property: "scale"; to: 1.0; duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase }
                }
            }

            Text {
                id: alertsDndIcon
                z: 2
                anchors.centerIn: parent
                text: ShellState.dndActive ? "󰂛" : "󰂚"
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: Theme.text
                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                layer.enabled: ShellState.liquidGlassEnabled
                layer.effect: DropShadow {
                    verticalOffset: 1
                    radius: 4
                    samples: 9
                    color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
                }
            }

            MouseArea {
                id: dndMouse
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.dndActive = !ShellState.dndActive
            }
        }

        // Minimal Clear All Button
        GlassBox {
            id: clearBtn
            autoLiquidGlass: false
            implicitWidth: 32
            implicitHeight: 32
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            cornerRadius: 16
            hovered: clearMouse.containsMouse
            pressed: clearMouse.pressed
            color: alertsTab.liquidActive ? "transparent" : (clearMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
            border.width: alertsTab.liquidActive ? 0 : 1

            LiquidGlassLens {
                anchors.fill: parent
                z: 0
                lensScreenX: alertsTab.liquidCardBaseX + clearBtn.x * alertsTab.panelScaleX
                lensScreenY: alertsTab.liquidCardBaseY - 42 * alertsTab.panelScaleY + clearBtn.y * alertsTab.panelScaleY
                lensScreenW: clearBtn.width * alertsTab.panelScaleX
                lensScreenH: clearBtn.height * alertsTab.panelScaleY
                cornerRadius: clearBtn.cornerRadius
                bevelWidth: 0.24
                tintColor: clearMouse.containsMouse
                    ? (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.24) : Qt.rgba(0.22, 0.26, 0.34, 0.14))
                    : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(0.16, 0.19, 0.26, 0.08))
                rimColor: clearMouse.containsMouse
                    ? Qt.rgba(1.0, 1.0, 1.0, 0.90)
                    : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.72))
            }

            Text {
                z: 2
                anchors.centerIn: parent
                text: "󰃢"
                font.family: Theme.iconFont
                font.pixelSize: 14
                color: Theme.text
                layer.enabled: ShellState.liquidGlassEnabled
                layer.effect: DropShadow {
                    verticalOffset: 1
                    radius: 4
                    samples: 9
                    color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
                }
            }

            MouseArea {
                id: clearMouse
                anchors.fill: parent
                z: 3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.clearAllHistory()
            }
        }
    }

    // Unified Container for Empty State & Active Notifications List (Smooth Crossfade!)
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Compact Empty "All caught up" Glass Card
        GlassBox {
            id: emptyCard
            autoLiquidGlass: false
            anchors.top: parent.top
            width: parent.width
            height: 82
            cornerRadius: 16
            color: alertsTab.liquidActive ? "transparent" : Qt.rgba(0.05, 0.06, 0.10, 0.34)
            border.width: alertsTab.liquidActive ? 0 : 1
            border.color: alertsTab.liquidActive ? "transparent" : Qt.rgba(1.0, 1.0, 1.0, 0.14)
            opacity: ShellState.notifHistoryModel.count === 0 ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            LiquidGlassLens {
                anchors.fill: parent
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                z: 0
                lensScreenX: alertsTab.liquidCardBaseX
                lensScreenY: alertsTab.liquidCardBaseY
                lensScreenW: emptyCard.width * alertsTab.panelScaleX
                lensScreenH: emptyCard.height * alertsTab.panelScaleY
                cornerRadius: emptyCard.cornerRadius
            }

            RowLayout {
                z: 2
                anchors.centerIn: parent
                spacing: 12
                layer.enabled: ShellState.liquidGlassEnabled
                layer.effect: DropShadow {
                    verticalOffset: 1
                    radius: 5
                    samples: 11
                    color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
                }

                GlassBadge {
                    badgeSize: 40
                    iconSize: 18
                    active: false
                    icon: "󰂚"
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "All caught up"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: Theme.text
                    }
                    Text {
                        text: "No new notifications"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }
            }
        }

        // Active Notifications ListView (Balanced Smooth Scroll + Multi-Stop Alpha Top/Bottom Fade)
        ListView {
            id: alertsListView
            anchors.fill: parent
            clip: true
            spacing: 8
            topMargin: 0
            bottomMargin: 0
            model: ShellState.notifHistoryModel
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            opacity: ShellState.notifHistoryModel.count > 0 ? 1.0 : 0.0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            header: Item { width: alertsListView.width; height: 6 }
            footer: Item { width: alertsListView.width; height: 18 }

            property real scrollTargetY: 0
            readonly property real topFade: Math.min(1.0, Math.max(0.0, contentY / 14.0))
            readonly property real botFade: Math.min(1.0, Math.max(0.0, (contentHeight - height - contentY) / 14.0))

            Behavior on contentY {
                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }

            Connections {
                target: ShellState.notifHistoryModel
                function onCountChanged() {
                    const maxContentY = Math.max(0, alertsListView.contentHeight - alertsListView.height);
                    if (alertsListView.scrollTargetY > maxContentY) {
                        alertsListView.scrollTargetY = maxContentY;
                        alertsListView.contentY = maxContentY;
                    }
                }
            }

            Connections {
                target: ShellState
                function onNotifCenterOpenChanged() {
                    if (ShellState.notifCenterOpen) {
                        alertsListView.scrollTargetY = 0;
                        alertsListView.contentY = 0;
                    }
                }
            }

            // Balanced, accumulating mouse wheel & touchpad scrolling
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const maxContentY = Math.max(0, alertsListView.contentHeight - alertsListView.height);
                    if (maxContentY <= 0) return;
                    const delta = event.angleDelta.y;
                    const step = (delta !== 0 ? (delta / 120.0) : (event.pixelDelta.y / 18.0)) * 115;
                    alertsListView.scrollTargetY = Math.max(0, Math.min(maxContentY, alertsListView.scrollTargetY - step));
                    alertsListView.contentY = alertsListView.scrollTargetY;
                    event.accepted = true;
                }
            }

            // Multi-stop perceptual ease-out alpha OpacityMask (reaches 0 alpha inside clip bounds so no hard cut ever appears)
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Item {
                    width: Math.max(1, alertsListView.width)
                    height: Math.max(1, alertsListView.height)

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0 - alertsListView.topFade) }
                            GradientStop { position: 0.018; color: Qt.rgba(1, 1, 1, 1.0 - alertsListView.topFade) }
                            GradientStop { position: 0.048; color: Qt.rgba(1, 1, 1, 1.0 - 0.72 * alertsListView.topFade) }
                            GradientStop { position: 0.085; color: Qt.rgba(1, 1, 1, 1.0 - 0.32 * alertsListView.topFade) }
                            GradientStop { position: 0.13; color: "#ffffffff" }
                            GradientStop { position: 0.85; color: "#ffffffff" }
                            GradientStop { position: 0.895; color: Qt.rgba(1, 1, 1, 1.0 - 0.32 * alertsListView.botFade) }
                            GradientStop { position: 0.942; color: Qt.rgba(1, 1, 1, 1.0 - 0.75 * alertsListView.botFade) }
                            GradientStop { position: 0.982; color: Qt.rgba(1, 1, 1, 1.0 - alertsListView.botFade) }
                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.0 - alertsListView.botFade) }
                        }
                    }
                }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 210; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; to: 0.94; duration: 210; easing.type: Easing.OutCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { property: "y"; duration: 190; easing.type: Easing.OutCubic }
            }

            delegate: GlassBox {
                id: notifCard
                autoLiquidGlass: false
                required property var model
                required property int index

                width: alertsListView.width
                height: notifCol.implicitHeight + 22
                cornerRadius: 16
                hovered: cardMouse.containsMouse
                pressed: cardMouse.pressed
                color: alertsTab.liquidActive
                    ? "transparent"
                    : (cardMouse.containsMouse ? Qt.rgba(0.08, 0.09, 0.13, 0.48) : Qt.rgba(0.05, 0.06, 0.10, 0.36))
                border.width: alertsTab.liquidActive ? 0 : 1
                border.color: alertsTab.liquidActive
                    ? "transparent"
                    : (cardMouse.containsMouse ? Qt.rgba(1.0, 1.0, 1.0, 0.22) : Qt.rgba(1.0, 1.0, 1.0, 0.14))

                LiquidGlassLens {
                    anchors.fill: parent
                    anchors.leftMargin: 1
                    anchors.rightMargin: 1
                    z: 0
                    readonly property real screenY: alertsTab.liquidCardBaseY + (notifCard.y - alertsListView.contentY + notifCard.enterOffsetY + notifCard.clearOffsetY) * alertsTab.panelScaleY
                    lensScreenX: alertsTab.liquidCardBaseX
                    lensScreenY: screenY
                    lensScreenW: notifCard.width * alertsTab.panelScaleX
                    lensScreenH: notifCard.height * alertsTab.panelScaleY
                    cornerRadius: notifCard.cornerRadius
                    tintColor: cardMouse.containsMouse
                        ? (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.24) : Qt.rgba(0.24, 0.28, 0.36, 0.14))
                        : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(0.16, 0.19, 0.26, 0.08))
                    rimColor: cardMouse.containsMouse
                        ? Qt.rgba(1.0, 1.0, 1.0, 0.88)
                        : (Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.72))
                }

                property real enterOffsetY: 0
                property real enterOpacity: 1.0
                property real enterScale: 1.0

                property real clearOffsetY: 0
                property real clearOpacity: 1.0
                property real clearScale: 1.0

                opacity: enterOpacity * clearOpacity
                transform: [
                    Translate {
                        y: notifCard.enterOffsetY + notifCard.clearOffsetY
                    },
                    Scale {
                        origin.x: notifCard.width * 0.5
                        origin.y: notifCard.height * 0.5
                        xScale: notifCard.enterScale * notifCard.clearScale
                        yScale: notifCard.enterScale * notifCard.clearScale
                    }
                ]

                function startEnterAnim(delayMs) {
                    enterAnim.stop();
                    notifCard.enterOffsetY = 20;
                    notifCard.enterOpacity = 0.0;
                    notifCard.enterScale = 0.94;
                    enterPause.duration = Math.max(0, Math.round(delayMs));
                    enterAnim.restart();
                }

                Component.onCompleted: {
                    const elapsed = Date.now() - ShellState.notifCenterOpenedAt;
                    if (ShellState.notifCenterOpen && elapsed >= 0 && elapsed < 360) {
                        const delay = Math.max(0, 25 + Math.min(notifCard.index, 5) * 40 - elapsed);
                        notifCard.startEnterAnim(delay);
                    }
                }

                Connections {
                    target: ShellState
                    function onNotifCenterOpenChanged() {
                        if (ShellState.notifCenterOpen) {
                            notifCard.clearOffsetY = 0;
                            notifCard.clearOpacity = 1.0;
                            notifCard.clearScale = 1.0;
                            notifCard.startEnterAnim(25 + Math.min(notifCard.index, 5) * 40);
                        }
                    }
                }

                SequentialAnimation {
                    id: enterAnim
                    PauseAnimation {
                        id: enterPause
                        duration: 0
                    }
                    ParallelAnimation {
                        NumberAnimation { target: notifCard; property: "enterOffsetY"; to: 0; duration: 240; easing.type: Easing.OutCubic }
                        NumberAnimation { target: notifCard; property: "enterOpacity"; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                        NumberAnimation { target: notifCard; property: "enterScale"; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
                    }
                }

                SequentialAnimation {
                    id: clearAnim
                    running: ShellState.isClearingHistory
                    PauseAnimation { duration: Math.max(0, Math.min(notifCard.index, 6)) * 65 }
                    ParallelAnimation {
                        NumberAnimation { target: notifCard; property: "clearOffsetY"; to: -18; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: notifCard; property: "clearOpacity"; to: 0.0; duration: 240; easing.type: Easing.OutCubic }
                        NumberAnimation { target: notifCard; property: "clearScale"; to: 0.94; duration: 260; easing.type: Easing.OutCubic }
                    }
                }

                // Background Click Area (z: 0 so dismissMouse at z: 10 is never blocked!)
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    z: 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ShellState.activateHistoryNotification(notifCard.index);
                    }
                }

                ColumnLayout {
                    id: notifCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 11
                    spacing: 5
                    z: 2
                    layer.enabled: ShellState.liquidGlassEnabled
                    layer.effect: DropShadow {
                        verticalOffset: 1
                        radius: 5
                        samples: 11
                        color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.25 : 0.80)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: Theme.glassCard
                            border.color: Theme.glassBorder
                            border.width: 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                visible: notifCard.model.isFileImg && notifCard.model.iconSrc.length > 0
                                source: notifCard.model.isFileImg ? notifCard.model.iconSrc : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            IconImage {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                visible: !notifCard.model.isFileImg && notifCard.model.iconSrc.length > 0
                                source: (!notifCard.model.isFileImg && notifCard.model.iconSrc.length > 0) ? Quickshell.iconPath(notifCard.model.iconSrc) : ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !notifCard.model.iconSrc || notifCard.model.iconSrc.length === 0
                                text: "󰂚"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: Theme.text
                            }
                        }

                        Text {
                            text: notifCard.model.appName || "Notification"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.subtext
                        }

                        Text {
                            text: notifCard.model.time ? ("• " + notifCard.model.time) : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                        }

                        Item { Layout.fillWidth: true }

                        // Dismiss '✕' Button (z: 10)
                        Rectangle {
                            z: 10
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: dismissMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                            border.color: dismissMouse.containsMouse ? Theme.glassHighlight : "transparent"
                            border.width: 1
                            scale: dismissMouse.pressed ? 0.88 : (dismissMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 120) } }
                            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(160, 120) } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: dismissMouse.containsMouse ? Theme.text : Theme.subtext
                                Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 120) } }
                            }

                            MouseArea {
                                id: dismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    ShellState.dismissFromHistory(notifCard.index);
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: notifCard.model.summary || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: notifCard.model.body && notifCard.model.body.length > 0
                        text: notifCard.model.body || ""
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.subtext
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
