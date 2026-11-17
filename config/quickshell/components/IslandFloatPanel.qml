import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "./cc"

// Content overlay synchronized 1:1 to ScreenFrame's single Center Dynamic Island.
// Draws no duplicate background or pill — the Dynamic Island itself transforms into the panel.
PanelWindow {
    id: root

    required property bool open
    required property string modalMode
    required property string layerNamespace
    property real subLayoutRev: 0
    default property alias cardData: innerContent.data

    signal closeRequested()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: 0
        bottom: 0
        left: 0
        right: 0
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    // Keep the layer surface pre-mapped so frame 0 renders seamlessly alongside ScreenFrame;
    // pointer events pass through completely whenever closed via the 0x0 Region mask.
    visible: true

    property bool isClosingSelf: false
    property real modalCrossfade: 1.0
    readonly property bool dockSettled: !ShellState.isModalMorphing
        && ShellState.centerIslandY <= Theme.barTopGap + 2
        && ShellState.centerIslandHeight <= Theme.barHeight + 4
    readonly property bool panelVisible: root.open || (root.isClosingSelf && !root.dockSettled)

    NumberAnimation {
        id: modalCrossfadeAnim
        target: root
        property: "modalCrossfade"
        from: 0.0
        to: 1.0
        duration: ShellState.animDur(290, 210)
        easing.type: ShellState.animPrimaryEase
    }

    onOpenChanged: {
        if (root.open) {
            root.isClosingSelf = false;
            if (ShellState.centerIslandHeight > Theme.barHeight + 20) {
                modalCrossfadeAnim.restart();
            } else {
                modalCrossfadeAnim.stop();
                root.modalCrossfade = 1.0;
            }
        } else {
            modalCrossfadeAnim.stop();
            root.modalCrossfade = 1.0;
            root.isClosingSelf = !root.dockSettled;
        }
    }

    Connections {
        target: ShellState
        function onCenterIslandModeChanged() {
            if (ShellState.isFloatingModalMode && ShellState.centerIslandMode !== root.modalMode) {
                root.isClosingSelf = false;
            }
        }
    }

    onDockSettledChanged: {
        if (!root.open && root.dockSettled) {
            root.isClosingSelf = false;
        }
    }

    Item {
        id: inputMaskProxy
        x: 0
        y: 0
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }
    mask: Region { item: inputMaskProxy }

    readonly property real destW: ShellState.modalDestWidth(root.modalMode)
    readonly property real destH: ShellState.modalDestHeight(root.modalMode)
    readonly property real widthProgress: Math.max(0.0, (ShellState.centerIslandWidth - ShellState.centerIslandBaseWidth) / Math.max(1.0, root.destW - ShellState.centerIslandBaseWidth))
    readonly property real heightProgress: Math.max(0.0, (ShellState.centerIslandHeight - Theme.barHeight) / Math.max(1.0, root.destH - Theme.barHeight))

    function smoothstep01(val) {
        const t = Math.min(1.0, Math.max(0.0, val));
        return t * t * (3.0 - 2.0 * t);
    }

    Item {
        anchors.fill: parent
        visible: root.panelVisible

        DesktopCaptureSource {
            id: floatCap
            targetScreen: root.screen
            sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
            sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
            active: ShellState.liquidGlassEnabled && root.panelVisible
        }

        // Transparent click-outside catcher so clicks outside the Dynamic Island dismiss it
        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: root.closeRequested()
        }

        // Clipped directly to ScreenFrame's live Center Dynamic Island bounds
        Item {
            id: cardClip
            x: (parent.width - width) / 2
            y: ShellState.centerIslandY
            width: Math.max(1, ShellState.centerIslandWidth)
            height: Math.max(1, ShellState.centerIslandHeight)
            clip: true

            // Swallow clicks inside the card so they don't hit the backdrop MouseArea
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            BottomGlassWave {
                z: 20
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                panelWidth: parent.width
                panelHeight: parent.height
                cornerRadius: ShellState.centerIslandRadius
                intensity: 1.0
                active: ShellState.liquidGlassEnabled && ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && root.open && ShellState.centerIslandHeight > Theme.barHeight + 2
                    && (ShellState.centerIslandMode === "launcher" || ShellState.centerIslandMode === "clipboard" || ShellState.centerIslandMode === "settings" || ShellState.centerIslandMode === "cheatSheet")
            }

            FocusScope {
                id: innerContent
                readonly property bool liquidGlassHost: true
                readonly property var liquidSource: floatCap.textureSource
                readonly property bool liquidSourceReady: floatCap.ready
                readonly property real liquidOriginX: 0
                readonly property real liquidOriginY: 0
                readonly property real liquidLayoutRev: ShellState.centerIslandWidth
                    + ShellState.centerIslandHeight * 3.0
                    + root.widthProgress * 100.0
                    + root.heightProgress * 100.0
                    + ShellState.settingsTab * 13.0
                    + root.subLayoutRev

                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: root.destW
                height: root.destH
                focus: root.open
                opacity: (root.isClosingSelf
                    ? root.smoothstep01((root.heightProgress - 0.42) / 0.45)
                    : root.smoothstep01((root.heightProgress - 0.25) / 0.52)) * root.modalCrossfade

                Keys.onEscapePressed: root.closeRequested()

                transform: Scale {
                    origin.x: root.destW / 2
                    origin.y: root.destH / 2
                    xScale: 0.74 + 0.26 * Math.min(1.08, root.widthProgress)
                    yScale: 0.74 + 0.26 * Math.min(1.08, root.heightProgress)
                }
            }
        }
    }
}
