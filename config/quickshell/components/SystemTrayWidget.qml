import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."

Rectangle {
    id: root

    property var targetScreen: null
    readonly property var trayItems: (SystemTray.items && SystemTray.items.values) ? SystemTray.items.values : []
    property int hoveredCount: 0
    readonly property bool isPillHighlighted: hoveredCount > 0

    visible: trayItems.length > 0
    implicitHeight: 26
    implicitWidth: trayItems.length > 0 ? trayRow.implicitWidth : 0
    radius: 0
    color: "transparent"
    border.width: 0

    function focusWindow(item) {
        if (!item) return;
        const rawId = (item.id || "").toLowerCase();
        const rawTitle = (item.title || "").toLowerCase();
        let appName = "";
        if (rawId.includes("discord") || rawTitle.includes("discord")) appName = "discord";
        else if (rawId.includes("antigravity") || rawTitle.includes("antigravity")) appName = "antigravity";
        else if (rawId.includes("steam") || rawTitle.includes("steam")) appName = "steam";
        else if (rawId.includes("spotify") || rawTitle.includes("spotify")) appName = "spotify";
        else if (rawId.includes("slack") || rawTitle.includes("slack")) appName = "slack";
        else if (rawId.includes("telegram") || rawTitle.includes("telegram")) appName = "telegram";
        else if (item.id && item.id.length > 0) {
            appName = item.id.split(/[-_]/)[0].toLowerCase();
        }

        if (appName) {
            ShellState.dispatchHypr("hl.dsp.focus({ window = 'class:" + appName + "' })", "focuswindow class:" + appName);
        }
    }

    function openTrayMenu(trayBox, item) {
        if (!item) return;
        if (item.hasMenu && item.menu) {
            ShellState.activateMonitor(root.targetScreen);
            const pos = trayBox.mapToItem(null, 0, 0);
            const centerX = pos.x + trayBox.width / 2;
            const screenW = root.Window.window ? root.Window.window.width : 3440;
            const maxRight = screenW - Theme.barMarginX;
            const rightX = Math.min(maxRight, Math.max(ShellState.trayMenuTargetWidth + Theme.barMarginX, centerX + ShellState.trayMenuTargetWidth / 2));
            ShellState.openOrSwitchTrayMenu(item.menu, item.title || item.id || "", centerX, rightX);
        } else {
            item.secondaryActivate();
        }
    }

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: root.trayItems

            delegate: Rectangle {
                id: trayBox
                required property var modelData
                readonly property bool isHovering: trayMouse.containsMouse
                onIsHoveringChanged: root.hoveredCount = Math.max(0, root.hoveredCount + (isHovering ? 1 : -1))
                Component.onDestruction: {
                    if (isHovering) root.hoveredCount = Math.max(0, root.hoveredCount - 1);
                }

                width: 22
                height: 20
                radius: 10
                color: trayLg.isLiquidActive ? "transparent" : (trayMouse.containsMouse ? Theme.glassSurfaceHover : "transparent")

                LiquidGlassSurface {
                    id: trayLg
                    anchors.fill: parent
                    z: -1
                    cornerRadius: 10
                    hovered: trayMouse.containsMouse
                    onlyWhenHighlighted: true
                }

                scale: trayMouse.pressed ? 0.88 : (trayMouse.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 130 } }

                IconImage {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    source: (trayBox.modelData && trayBox.modelData.icon) ? trayBox.modelData.icon : ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: trayIcon.status !== Image.Ready
                    text: "󰀻"
                    font.family: Theme.iconFont
                    font.pixelSize: 12
                    color: Theme.text
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: mouse => {
                        const item = trayBox.modelData;
                        if (!item) return;

                        if (mouse.button === Qt.RightButton) {
                            root.openTrayMenu(trayBox, item);
                        } else if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else {
                            if (item.onlyMenu) {
                                root.openTrayMenu(trayBox, item);
                            } else {
                                item.activate();
                                root.focusWindow(item);
                            }
                        }
                    }

                    onWheel: wheel => {
                        const item = trayBox.modelData;
                        if (!item) return;
                        if (wheel.angleDelta.y !== 0) {
                            item.scroll(wheel.angleDelta.y, false);
                        } else if (wheel.angleDelta.x !== 0) {
                            item.scroll(wheel.angleDelta.x, true);
                        }
                    }
                }
            }
        }
    }
}
