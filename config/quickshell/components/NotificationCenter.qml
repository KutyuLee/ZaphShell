import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "./cc"

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
    readonly property real h: Math.max(0, ShellState.rightIslandHeight - Theme.barHeight)
    readonly property real targetW: ShellState.targetNotifCenterWidth
    readonly property real targetH: Math.max(1, ShellState.targetNotifCenterHeight)
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, (ShellState.smoothRightIslandHeight - Theme.barHeight) / Math.max(1, targetH)))
    readonly property real rightOffset: Theme.barMarginX
    readonly property bool isActiveRight: ShellState.notifCenterOpen || ShellState.rightIslandOwner === "notifCenter"

    implicitWidth: targetW + Theme.barMarginX + 56
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notif-center"
    WlrLayershell.keyboardFocus: ShellState.notifCenterOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: h > 0.5 && isActiveRight
    mask: Region { item: ncContent }

    HyprlandFocusGrab {
        active: ShellState.notifCenterOpen && root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: {
            ShellState.notifCenterOpen = false;
        }
    }

    Item {
        focus: ShellState.notifCenterOpen
        Keys.onEscapePressed: ShellState.notifCenterOpen = false
    }

    DesktopCaptureSource {
        id: ncCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    // Aligned flush with ScreenFrame's Right Morphing Island (starts at y=0 immediately below the 38px bar header)
    Item {
        id: ncContent
        x: root.width - root.rightOffset - ShellState.rightIslandWidth
        y: 0
        width: Math.max(1, ShellState.rightIslandWidth)
        height: Math.max(1, root.h)
        clip: true

        BottomGlassWave {
            z: 20
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: ShellState.rightIslandRadius
            intensity: 1.0
            active: ShellState.liquidGlassEnabled && ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && ShellState.notifCenterOpen && ShellState.rightIslandHeight > Theme.barHeight + 2
        }

        // Subtle inset glass divider between the Right Island header row and Notification Center body
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            color: Theme.glassBorder
        }

        Item {
            id: ncScaled
            readonly property real scaleX: ShellState.rightIslandWidth / Math.max(1, root.targetW)
            readonly property real scaleY: (0.72 + 0.28 * root.smoothHRatio) * ShellState.rightIslandDeformScaleY
            width: root.targetW
            height: root.targetH
            anchors.top: parent.top
            anchors.right: parent.right

            transform: Scale {
                origin.x: root.targetW
                origin.y: 0
                xScale: ncScaled.scaleX
                yScale: ncScaled.scaleY
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 12
                anchors.bottomMargin: 16

                AlertsTab {
                    activeTab: 2
                    desktopSource: ncCap.textureSource
                    desktopSourceReady: ncCap.ready
                    screenWidth: ShellState.mainScreenWidth
                    screenHeight: ShellState.mainScreenHeight
                    panelScaleX: ncScaled.scaleX
                    panelScaleY: ncScaled.scaleY
                    liquidCardBaseX: (ShellState.mainScreenWidth - root.rightOffset) - (root.targetW - 16) * ncScaled.scaleX
                    liquidCardBaseY: Theme.barBottomY + 54 * ncScaled.scaleY
                }
            }
        }
    }
}
