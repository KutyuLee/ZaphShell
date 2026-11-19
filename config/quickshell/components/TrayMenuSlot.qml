import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: slot

    property real screenW: 1920
    property real panelWidth: 520
    property var desktopTextureSource: null
    property bool desktopSourceReady: false
    property bool isActiveSlot: false

    property var menuSource: null
    property real centerX: 3000
    property bool isOpen: false
    property real targetW: 160
    property real targetH: 180
    property real animW: 44
    property real animH: 0
    property real smoothH: isOpen ? targetH : 0
    Behavior on smoothH { NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }

    readonly property real collapsedW: Math.min(targetW, 44)
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, smoothH / Math.max(1, targetH)))
    readonly property real deformScaleY: Math.max(0.86, Math.min(1.12, animH / Math.max(1, smoothH)))
    readonly property bool isVisible: animH > 0.5 || isOpen
    readonly property real minCenterX: Theme.barMarginX + targetW / 2
    readonly property real maxCenterX: screenW - Theme.barMarginX - targetW / 2
    readonly property real clampedCenterX: Math.max(minCenterX, Math.min(maxCenterX, centerX))
    readonly property bool useLiquid: ShellState.liquidGlassEnabled && desktopSourceReady

    function resetCollapsed() {
        openAnim.stop();
        closeAnim.stop();
        resizeAnim.stop();
        animW = collapsedW;
        animH = 0;
    }

    function recalc() {
        const list = (slotOpener.children && slotOpener.children.values) ? slotOpener.children.values : [];
        if (!list || list.length === 0) {
            if (menuCol && menuCol.implicitHeight > 10) {
                targetH = Math.max(44, Math.min(460, menuCol.implicitHeight + 16));
            } else {
                targetH = 52;
                targetW = 140;
            }
        } else {
            let totalH = 16;
            let maxRowW = 80;
            for (let i = 0; i < list.length; ++i) {
                const it = list[i];
                if (!it || it.visible === false) continue;
                if (it.isSeparator) {
                    totalH += 9;
                } else {
                    totalH += 30;
                    const clean = it.text ? it.text.replace(/_/g, "") : "";
                    itemLabelMetrics.text = clean;
                    let rowW = 16 + Math.ceil(itemLabelMetrics.advanceWidth);
                    if (it.buttonType !== QsMenuButtonType.None) rowW += 21;
                    if (it.icon && it.icon.length > 0) rowW += 22;
                    if (it.hasChildren) rowW += 20;
                    if (rowW > maxRowW) maxRowW = rowW;
                }
            }
            targetH = Math.max(44, Math.min(460, totalH));
            targetW = Math.max(112, Math.min(260, maxRowW + 16));
        }
        if (isOpen && isActiveSlot) {
            ShellState.trayMenuTargetWidth = targetW;
            ShellState.trayMenuTargetHeight = targetH;
        }
        if (isOpen) triggerMorph();
    }

    function triggerMorph() {
        if (!isOpen) {
            openAnim.stop();
            resizeAnim.stop();
            closeWAnim.from = animW;
            closeWAnim.to = collapsedW;
            closeHAnim.from = animH;
            closeHAnim.to = 0;
            closeAnim.restart();
            return;
        }
        closeAnim.stop();
        if (animH > 6 && !openAnim.running) {
            resizeWAnim.to = targetW;
            resizeHAnim.to = targetH;
            resizeAnim.restart();
        } else {
            resizeAnim.stop();
            openAnim.stop();
            openW1Anim.to = targetW * (ShellState.isSnappyAnimations ? 1.018 : 1.014);
            openW2Anim.to = targetW;
            openH1Anim.to = targetH * (ShellState.isSnappyAnimations ? 1.022 : 1.016);
            openH2Anim.to = targetH;
            openAnim.restart();
        }
    }

    onIsOpenChanged: triggerMorph()

    TextMetrics {
        id: itemLabelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    QsMenuOpener {
        id: slotOpener
        menu: slot.menuSource
        onChildrenChanged: slot.recalc()
    }

    ParallelAnimation {
        id: openAnim
        SequentialAnimation {
            NumberAnimation {
                id: openW1Anim
                target: slot
                property: "animW"
                to: slot.targetW * 1.018
                duration: ShellState.animDur(340, 235)
                easing.type: ShellState.animPrimaryEase
            }
            NumberAnimation {
                id: openW2Anim
                target: slot
                property: "animW"
                to: slot.targetW
                duration: ShellState.animDur(220, 155)
                easing.type: Easing.InOutSine
            }
        }
        SequentialAnimation {
            NumberAnimation {
                id: openH1Anim
                target: slot
                property: "animH"
                to: slot.targetH * 1.022
                duration: ShellState.animDur(360, 250)
                easing.type: ShellState.animPrimaryEase
            }
            NumberAnimation {
                id: openH2Anim
                target: slot
                property: "animH"
                to: slot.targetH
                duration: ShellState.animDur(220, 155)
                easing.type: Easing.InOutSine
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            id: closeWAnim
            target: slot
            property: "animW"
            to: slot.collapsedW
            duration: ShellState.animDur(300, 190)
            easing.type: ShellState.animPrimaryEase
        }
        NumberAnimation {
            id: closeHAnim
            target: slot
            property: "animH"
            to: 0
            duration: ShellState.animDur(300, 190)
            easing.type: ShellState.animPrimaryEase
        }
    }

    ParallelAnimation {
        id: resizeAnim
        NumberAnimation {
            id: resizeWAnim
            target: slot
            property: "animW"
            to: slot.targetW
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: resizeHAnim
            target: slot
            property: "animH"
            to: slot.targetH
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    visible: isVisible
    x: clampedCenterX - (screenW - panelWidth) - width / 2
    y: Theme.barBottomY + 4
    width: Math.max(1, animW)
    height: Math.max(1, animH)
    radius: Math.min(width / 2, height / 2, 22)
    color: "transparent"
    border.width: 0

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: !slot.useLiquid
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
        visible: slot.useLiquid
        desktopSource: slot.desktopTextureSource
        screenX: slot.screenW - slot.panelWidth + slot.x
        screenY: slot.y
        screenW: slot.width
        screenH: slot.height
        cornerRadius: slot.radius
        bevelWidth: 0.16
    }

    Item {
        id: menuContent
        readonly property bool liquidGlassHost: true
        readonly property var liquidSource: slot.desktopTextureSource
        readonly property bool liquidSourceReady: slot.desktopSourceReady
        readonly property real liquidOriginX: slot.screenW - slot.panelWidth
        readonly property real liquidOriginY: 0
        readonly property int liquidLayoutRev: Math.round(slot.animW + slot.animH * 3)
        anchors.fill: parent
        clip: true

        Item {
            width: slot.targetW
            height: slot.targetH
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            transform: Scale {
                origin.x: slot.targetW / 2
                origin.y: 0
                xScale: slot.animW / Math.max(1, slot.targetW)
                yScale: (0.72 + 0.28 * slot.smoothHRatio) * slot.deformScaleY
            }

            Column {
                id: menuCol
                x: 8
                y: 8
                width: Math.max(96, slot.targetW - 16)
                spacing: 2

                onImplicitHeightChanged: {
                    if (implicitHeight > 10) {
                        slot.targetH = Math.max(44, Math.min(460, implicitHeight + 16));
                        if (slot.isOpen) slot.triggerMorph();
                    }
                }

                Repeater {
                    model: slotOpener.children

                    delegate: Item {
                        id: entryItem
                        required property var modelData

                        readonly property bool isVisible: entryItem.modelData ? (entryItem.modelData.visible !== false) : false
                        visible: entryItem.isVisible
                        width: menuCol.width
                        height: entryItem.isVisible ? ((entryItem.modelData && entryItem.modelData.isSeparator) ? 9 : 28) : 0

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - 12
                            height: 1
                            visible: entryItem.modelData && entryItem.modelData.isSeparator
                            color: Theme.glassBorder
                            opacity: 0.65
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: entryItem.modelData && !entryItem.modelData.isSeparator
                            radius: 8
                            color: trayItemLg.isLiquidActive ? "transparent" : ((itemMouse.containsMouse && entryItem.modelData && entryItem.modelData.enabled)
                                ? Theme.glassSurfaceHover
                                : "transparent")

                            LiquidGlassSurface {
                                id: trayItemLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 8
                                onlyWhenHighlighted: true
                                hovered: itemMouse.containsMouse && entryItem.modelData && entryItem.modelData.enabled
                            }
                            scale: itemMouse.pressed ? 0.96 : (itemMouse.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 110 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    visible: entryItem.modelData && entryItem.modelData.buttonType !== QsMenuButtonType.None
                                    text: {
                                        if (!entryItem.modelData) return "";
                                        const isChecked = entryItem.modelData.checkState === Qt.Checked;
                                        if (entryItem.modelData.buttonType === QsMenuButtonType.CheckBox) {
                                            return isChecked ? "󰄲" : "󰄱";
                                        } else if (entryItem.modelData.buttonType === QsMenuButtonType.RadioButton) {
                                            return isChecked ? "󰄯" : "󰄰";
                                        }
                                        return "";
                                    }
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    color: Theme.text
                                }

                                IconImage {
                                    visible: entryItem.modelData && entryItem.modelData.icon && entryItem.modelData.icon.length > 0
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                    source: entryItem.modelData ? entryItem.modelData.icon : ""
                                }

                                Text {
                                    text: entryItem.modelData ? entryItem.modelData.text.replace(/_/g, "") : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: (entryItem.modelData && entryItem.modelData.enabled) ? Theme.text : Theme.textDim
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: entryItem.modelData && entryItem.modelData.hasChildren
                                    text: "󰅂"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: Theme.textDim
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (entryItem.modelData && entryItem.modelData.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor

                                onClicked: {
                                    const it = entryItem.modelData;
                                    if (!it || !it.enabled) return;
                                    if (typeof it.sendTriggered === "function") {
                                        it.sendTriggered();
                                    } else if (typeof it.triggered === "function") {
                                        it.triggered();
                                    }
                                    ShellState.trayMenuOpen = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
