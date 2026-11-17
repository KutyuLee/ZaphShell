import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

PanelWindow {
    id: root

    anchors {
        right: true
        top: true
        bottom: true
    }

    margins {
        right: 0
        top: 0
        bottom: 0
    }

    property var barWindow: null
    readonly property real screenW: root.screen ? root.screen.width : ShellState.mainScreenWidth
    readonly property real w: Math.max(0, ShellState.trayIslandWidth)
    readonly property real h: Math.max(0, ShellState.trayIslandHeight)
    readonly property real targetW: Math.max(112, ShellState.trayMenuTargetWidth)
    readonly property real targetH: Math.max(1, ShellState.trayMenuTargetHeight)
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, ShellState.smoothTrayIslandHeight / Math.max(1, targetH)))

    implicitWidth: Math.min(screenW, Math.max(520, ShellState.rightIslandBaseWidth + 220))
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-traymenu"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: ShellState.trayMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: h > 0.5 || ShellState.trayMenuOpen

    Item {
        id: menuCardMask
        x: menuCard.x
        y: menuCard.y
        width: (ShellState.trayMenuOpen || root.h > 0.5) ? menuCard.width : 0
        height: (ShellState.trayMenuOpen || root.h > 0.5) ? menuCard.height : 0
    }

    mask: Region { item: menuCardMask }

    HyprlandFocusGrab {
        active: ShellState.trayMenuOpen && root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: {
            ShellState.trayMenuOpen = false;
        }
    }

    Item {
        focus: ShellState.trayMenuOpen
        Keys.onEscapePressed: ShellState.trayMenuOpen = false
    }

    TextMetrics {
        id: itemLabelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    QsMenuOpener {
        id: menuOpener
        menu: ShellState.trayMenuSource

        onChildrenChanged: root.recalculateSize()
    }

    Connections {
        target: ShellState
        function onTrayMenuOpenChanged() {
            if (ShellState.trayMenuOpen) {
                root.recalculateSize();
            }
        }
        function onTrayMenuSourceChanged() {
            root.recalculateSize();
        }
    }

    function recalculateSize() {
        const list = (menuOpener.children && menuOpener.children.values) ? menuOpener.children.values : [];
        if (!list || list.length === 0) {
            if (menuCol && menuCol.implicitHeight > 10) {
                ShellState.trayMenuTargetHeight = Math.max(44, Math.min(460, menuCol.implicitHeight + 16));
            } else {
                ShellState.trayMenuTargetHeight = 52;
                ShellState.trayMenuTargetWidth = 140;
            }
        } else {
            let totalH = 16; // top & bottom padding
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
            ShellState.trayMenuTargetHeight = Math.max(44, Math.min(460, totalH));
            ShellState.trayMenuTargetWidth = Math.max(112, Math.min(260, maxRowW + 16));
        }

        const maxRight = root.screenW - Theme.barMarginX;
        ShellState.trayMenuRightX = Math.min(maxRight, Math.max(ShellState.trayMenuTargetWidth + Theme.barMarginX, ShellState.trayMenuCenterX + ShellState.trayMenuTargetWidth / 2));
    }

    DesktopCaptureSource {
        id: trayCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    // Compact floating pill extending directly under the clicked tray icon with only the needed width
    Rectangle {
        id: menuCard
        readonly property real minCenterX: Theme.barMarginX + root.targetW / 2
        readonly property real maxCenterX: root.screenW - Theme.barMarginX - root.targetW / 2
        readonly property real clampedCenterX: Math.max(minCenterX, Math.min(maxCenterX, ShellState.trayMenuCenterX))
        readonly property bool useLiquid: ShellState.liquidGlassEnabled && trayCap.ready

        x: clampedCenterX - (root.screenW - root.width) - width / 2
        y: Theme.barBottomY + 4
        width: Math.max(1, root.w)
        height: Math.max(1, root.h)
        radius: Math.min(width / 2, height / 2, 22)
        color: "transparent"
        border.width: 0

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !menuCard.useLiquid
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
            visible: menuCard.useLiquid
            desktopSource: trayCap.textureSource
            screenX: root.screenW - root.width + menuCard.x
            screenY: menuCard.y
            screenW: menuCard.width
            screenH: menuCard.height
            cornerRadius: menuCard.radius
            bevelWidth: 0.16
        }

        Item {
            id: menuContent
            readonly property bool liquidGlassHost: true
            readonly property var liquidSource: trayCap.textureSource
            readonly property bool liquidSourceReady: trayCap.ready
            readonly property real liquidOriginX: root.screenW - root.width
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
                    yScale: (0.72 + 0.28 * root.smoothHRatio) * ShellState.trayIslandDeformScaleY
                }

                Column {
                    id: menuCol
                    x: 8
                    y: 8
                    width: Math.max(96, root.targetW - 16)
                    spacing: 2

                    onImplicitHeightChanged: {
                        if (implicitHeight > 10) {
                            ShellState.trayMenuTargetHeight = Math.max(44, Math.min(460, implicitHeight + 16));
                        }
                    }

            Repeater {
                model: menuOpener.children

                delegate: Item {
                    id: entryItem
                    required property var modelData

                    readonly property bool isVisible: entryItem.modelData ? (entryItem.modelData.visible !== false) : false
                    visible: entryItem.isVisible
                    width: menuCol.width
                    height: entryItem.isVisible ? ((entryItem.modelData && entryItem.modelData.isSeparator) ? 9 : 28) : 0

                    // Separator line
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        height: 1
                        visible: entryItem.modelData && entryItem.modelData.isSeparator
                        color: Theme.glassBorder
                        opacity: 0.65
                    }

                    // Clickable Menu Item
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

                            // Checkbox or Radio indicator if applicable
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

                            // Icon image if present
                            IconImage {
                                visible: entryItem.modelData && entryItem.modelData.icon && entryItem.modelData.icon.length > 0
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
                                source: entryItem.modelData ? entryItem.modelData.icon : ""
                            }

                            // Label
                            Text {
                                text: entryItem.modelData ? entryItem.modelData.text.replace(/_/g, "") : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: (entryItem.modelData && entryItem.modelData.enabled) ? Theme.text : Theme.textDim
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Submenu indicator if hasChildren
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
}
