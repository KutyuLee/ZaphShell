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
        left: true
        top: true
        bottom: true
    }

    margins {
        left: 0
        top: 0
        bottom: 0
    }

    property var barWindow: null
    readonly property real h: Math.max(0, ShellState.leftIslandHeight - Theme.barHeight)
    readonly property real targetW: Math.max(Theme.sysMenuWidth, ShellState.leftIslandBaseWidth + 16)
    readonly property real targetH: Theme.sysMenuHeight
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, (ShellState.smoothLeftIslandHeight - Theme.barHeight) / Math.max(1, targetH)))

    implicitWidth: Math.max(Theme.sysMenuWidth, targetW) + Theme.barMarginX + 48
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-sysmenu"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: ShellState.sysMenuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: h > 0.5 || ShellState.sysMenuOpen

    Item {
        id: menuContentMask
        x: menuContent.x
        y: menuContent.y
        width: (root.h > 0.5 || ShellState.sysMenuOpen) ? menuContent.width : 0
        height: (root.h > 0.5 || ShellState.sysMenuOpen) ? menuContent.height : 0
    }

    mask: Region { item: menuContentMask }

    HyprlandFocusGrab {
        active: ShellState.sysMenuOpen && root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: {
            ShellState.sysMenuOpen = false;
        }
    }

    Item {
        focus: ShellState.sysMenuOpen
        Keys.onEscapePressed: ShellState.sysMenuOpen = false
    }

    DesktopCaptureSource {
        id: sysCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    // Aligned flush with ScreenFrame's Left Morphing Island (starts at y=Theme.barBottomY immediately below the 38px bar header)
    Item {
        id: menuContent
        readonly property bool liquidGlassHost: true
        readonly property var liquidSource: sysCap.textureSource
        readonly property bool liquidSourceReady: sysCap.ready
        readonly property real liquidOriginX: 0
        readonly property real liquidOriginY: 0
        readonly property int liquidLayoutRev: Math.round(ShellState.leftIslandWidth + ShellState.leftIslandHeight * 3)

        x: Theme.barMarginX
        y: Theme.barBottomY
        width: Math.max(1, ShellState.leftIslandWidth)
        height: Math.max(1, root.h)
        clip: true

        BottomGlassWave {
            z: 20
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: ShellState.leftIslandRadius
            intensity: 1.0
            active: ShellState.liquidGlassEnabled && ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && ShellState.sysMenuOpen && ShellState.leftIslandHeight > Theme.barHeight + 2
        }

        // Subtle inset glass divider between the Left Island header row and System Menu body
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
            width: root.targetW
            height: root.targetH
            anchors.top: parent.top
            anchors.left: parent.left
            opacity: Math.min(1.0, Math.max(0.0, root.smoothHRatio * 1.35))

            transform: Scale {
                origin.x: 0
                origin.y: 0
                xScale: ShellState.leftIslandWidth / Math.max(1, root.targetW)
                yScale: (0.72 + 0.28 * root.smoothHRatio) * ShellState.leftIslandDeformScaleY
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 12
                anchors.bottomMargin: 16
                spacing: 4

                // 1. macOS-style Header: "Arch Linux" (logo placeholder seamlessly filled by floatingArchLogo spatial morph)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 10

                    Item {
                        id: headerLogoSlot
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                    }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "Arch Linux"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        font.weight: Font.Bold
                        color: Theme.text
                    }

                    Text {
                        text: "Hyprland • " + ShellState.kernelVersion
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        color: Theme.subtext
                    }
                }
            }

            // Divider Line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassBorder
            }

            // 2. Applications & Quick Tools
            component MenuItem: Rectangle {
                id: itemRoot
                property string icon: ""
                property string label: ""
                property color iconColor: Theme.subtext
                signal triggered()

                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: 8
                color: sysItemLg.isLiquidActive ? "transparent" : (itemMouse.containsMouse ? Theme.glassSurfaceHover : "transparent")

                LiquidGlassSurface {
                    id: sysItemLg
                    anchors.fill: parent
                    z: -1
                    cornerRadius: 8
                    onlyWhenHighlighted: true
                    hovered: itemMouse.containsMouse
                }

                scale: itemMouse.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: itemRoot.icon
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                        color: itemRoot.iconColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: itemRoot.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ShellState.sysMenuOpen = false;
                        itemRoot.triggered();
                    }
                }
            }

            MenuItem {
                icon: "󰌌"
                label: "Keyboard Shortcuts..."
                onTriggered: ShellState.toggleCheatSheet()
            }

            MenuItem {
                icon: "󰒓"
                label: "System Settings..."
                onTriggered: ShellState.toggleSettings()
            }

            MenuItem {
                icon: "󰀻"
                label: "App Launcher"
                onTriggered: ShellState.launcherOpen = true
            }

            MenuItem {
                icon: "󰞷"
                label: "Terminal"
                onTriggered: ShellState.launchTerminal("")
            }

            MenuItem {
                icon: "󰹑"
                label: "Screenshot"
                onTriggered: Quickshell.execDetached([ShellState.script("screenshot.sh"), "--region", "--delay"])
            }

            // Divider Line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.glassBorder
            }

            // 3. Power & Session Options
            MenuItem {
                icon: "󰌾"
                label: "Lock Screen"
                iconColor: Theme.subtext
                onTriggered: ShellState.lockScreen()
            }

            MenuItem {
                icon: "󰤄"
                label: "Sleep"
                iconColor: Theme.subtext
                onTriggered: {
                    ShellState.lockScreen();
                    Quickshell.execDetached([ShellState.script("power-action.sh"), "suspend"]);
                }
            }

            MenuItem {
                icon: "󰍃"
                label: "Log Out..."
                iconColor: Theme.subtext
                onTriggered: ShellState.dispatchHypr("hl.dsp.exit()", "exit")
            }

            MenuItem {
                icon: "󰜉"
                label: "Restart..."
                iconColor: Theme.subtext
                onTriggered: Quickshell.execDetached(["systemctl", "reboot"])
            }

            MenuItem {
                icon: "󰐥"
                label: "Shut Down..."
                iconColor: Theme.red
                onTriggered: Quickshell.execDetached(["systemctl", "poweroff"])
            }
            }
        }
    }

    // Floating Arch Logo Spatial Morph: smoothly detaches from Bar's LauncherButton and glides into SystemMenu's header
    Item {
        id: floatingArchLogo
        z: 10

        readonly property bool isOpen: ShellState.sysMenuOpen
        readonly property real barLogoX: Theme.barMarginX + ShellState.archLogoBarX
        readonly property real barLogoY: Theme.barTopGap + (Theme.barHeight - 26) / 2
        readonly property real openLogoX: Theme.barMarginX + 14
        readonly property real openLogoY: Theme.barBottomY + 12 + (38 - 32) / 2
        readonly property int animDur: ShellState.animDur(360, 265)
        property bool initialized: false
        Component.onCompleted: initialized = true

        x: isOpen ? openLogoX : barLogoX
        y: isOpen ? openLogoY : barLogoY
        width: isOpen ? 32 : 26
        height: isOpen ? 32 : 26

        property real boxRadius: isOpen ? 10 : 13
        property real boxOpacity: isOpen ? 1.0 : 0.0
        property real iconSize: isOpen ? 18 : 15

        Behavior on x { enabled: floatingArchLogo.initialized; NumberAnimation { duration: floatingArchLogo.animDur; easing.type: ShellState.animPrimaryEase } }
        Behavior on y { enabled: floatingArchLogo.initialized; NumberAnimation { duration: floatingArchLogo.animDur; easing.type: ShellState.animPrimaryEase } }
        Behavior on width { enabled: floatingArchLogo.initialized; NumberAnimation { duration: floatingArchLogo.animDur; easing.type: ShellState.animPrimaryEase } }
        Behavior on height { enabled: floatingArchLogo.initialized; NumberAnimation { duration: floatingArchLogo.animDur; easing.type: ShellState.animPrimaryEase } }
        Behavior on boxRadius { enabled: floatingArchLogo.initialized; NumberAnimation { duration: floatingArchLogo.animDur; easing.type: ShellState.animPrimaryEase } }
        Behavior on boxOpacity { enabled: floatingArchLogo.initialized; NumberAnimation { duration: ShellState.animDur(320, 220); easing.type: ShellState.animPrimaryEase } }
        Behavior on iconSize { enabled: floatingArchLogo.initialized; NumberAnimation { duration: floatingArchLogo.animDur; easing.type: ShellState.animPrimaryEase } }

        Rectangle {
            anchors.fill: parent
            radius: floatingArchLogo.boxRadius
            color: (ShellState.liquidGlassEnabled && sysCap.ready) ? "transparent" : Theme.glassSurfaceHover
            border.width: 0
            border.color: "transparent"
            opacity: floatingArchLogo.boxOpacity

            LiquidGlassEffect {
                anchors.fill: parent
                z: -1
                visible: ShellState.liquidGlassEnabled && sysCap.ready && floatingArchLogo.boxOpacity > 0.01
                desktopSource: sysCap.textureSource
                screenX: floatingArchLogo.x
                screenY: floatingArchLogo.y
                screenW: Math.max(1, floatingArchLogo.width)
                screenH: Math.max(1, floatingArchLogo.height)
                cornerRadius: floatingArchLogo.boxRadius
                screenWidth: ShellState.mainScreenWidth
                screenHeight: ShellState.mainScreenHeight
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰣇"
            font.family: Theme.iconFont
            font.pixelSize: Math.round(floatingArchLogo.iconSize)
            color: Theme.text
        }
    }
}
