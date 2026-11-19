import QtQuick
import Quickshell
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
    readonly property real screenH: root.screen ? root.screen.height : ShellState.mainScreenHeight
    property int activeSlotIdx: 0
    readonly property var activeSlot: activeSlotIdx === 0 ? slot0 : slot1
    readonly property bool anySlotVisible: slot0.isVisible || slot1.isVisible

    implicitWidth: Math.min(screenW, Math.max(520, ShellState.rightIslandBaseWidth + 220))
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-traymenu"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: ShellState.trayMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: root.anySlotVisible || ShellState.trayMenuOpen

    Item {
        id: menuCardMask
        x: root.activeSlot.x
        y: root.activeSlot.y
        width: (ShellState.trayMenuOpen || root.activeSlot.animH > 0.5) ? root.activeSlot.width : 0
        height: (ShellState.trayMenuOpen || root.activeSlot.animH > 0.5) ? root.activeSlot.height : 0
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

    DesktopCaptureSource {
        id: trayCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    Connections {
        target: ShellState
        function onTrayMenuOpenChanged() {
            if (ShellState.trayMenuOpen) {
                const s = root.activeSlot;
                s.menuSource = ShellState.trayMenuSource;
                s.centerX = ShellState.trayMenuCenterX;
                s.recalc();
                s.isOpen = true;
            } else {
                slot0.isOpen = false;
                slot1.isOpen = false;
            }
        }
        function onTraySwitchSeqChanged() {
            if (!ShellState.trayMenuOpen) return;
            const prev = root.activeSlot;
            prev.isOpen = false;
            root.activeSlotIdx = 1 - root.activeSlotIdx;
            const next = root.activeSlot;
            next.resetCollapsed();
            next.menuSource = ShellState.trayMenuSource;
            next.centerX = ShellState.trayMenuCenterX;
            next.recalc();
            next.isOpen = true;
        }
    }

    TrayMenuSlot {
        id: slot0
        z: root.activeSlotIdx === 0 ? 2 : 1
        screenW: root.screenW
        panelWidth: root.width
        desktopTextureSource: trayCap.textureSource
        desktopSourceReady: trayCap.ready
        isActiveSlot: root.activeSlotIdx === 0
    }

    TrayMenuSlot {
        id: slot1
        z: root.activeSlotIdx === 1 ? 2 : 1
        screenW: root.screenW
        panelWidth: root.width
        desktopTextureSource: trayCap.textureSource
        desktopSourceReady: trayCap.ready
        isActiveSlot: root.activeSlotIdx === 1
    }
}
