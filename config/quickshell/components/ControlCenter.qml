import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import ".."
import "./cc"

PanelWindow {
    id: root

    anchors {
        top: true
    }

    margins {
        top: 0
    }

    // Driven by ShellState's Center Dynamic Island morph animations
    property var barWindow: null
    readonly property real w: Math.max(0, ShellState.ccWidth)
    readonly property real h: Math.max(0, ShellState.ccHeight)
    readonly property real targetW: Theme.ccMaxWidth
    readonly property real panelWidth: ShellState.centerIslandWidth
    readonly property real panelHeight: Math.max(1, ShellState.targetCcHeight)
    readonly property real wRatio: w / targetW
    readonly property real hRatio: h / panelHeight
    readonly property real openProgress: Math.min(wRatio, hRatio)

    function getActiveMprisPlayer() {
        if (ShellState.islandMediaPlayer) return ShellState.islandMediaPlayer;
        const preferred = ShellState.selectIslandMediaPlayer(false);
        if (preferred) return preferred;
        const list = (Mpris.players && Mpris.players.values) ? Mpris.players.values : [];
        return list.length > 0 ? list[0] : null;
    }

    readonly property int mprisPlayerCount: (Mpris.players && Mpris.players.values) ? Mpris.players.values.length : 0
    readonly property var mprisPlayer: getActiveMprisPlayer()
    readonly property var activeTab1Player: (ShellState.controlCenterOpen && panelContent.activeTab === 1) ? mediaTabView.player : null
    readonly property bool useAltTab1Player: root.activeTab1Player !== null
        && (mediaTabView.playerIndex > 0 || ShellState.displayedTrackTitle.length === 0)
    readonly property bool isMprisPlaying: mprisPlayer !== null && mprisPlayer.playbackState === MprisPlaybackState.Playing
    readonly property string mprisTitle: (mprisPlayer && mprisPlayer.trackTitle) ? String(mprisPlayer.trackTitle) : "Now Playing"
    readonly property string mprisArtist: (mprisPlayer && mprisPlayer.trackArtist) ? String(mprisPlayer.trackArtist) : "Unknown Artist"
    readonly property string mprisArtUrl: (mprisPlayer && mprisPlayer.trackArtUrl) ? String(mprisPlayer.trackArtUrl) : ""

    implicitWidth: Theme.ccMaxWidth + 80
    implicitHeight: Math.max(Theme.barBottomY + 460 + 48, ShellState.mainScreenHeight)
    color: "transparent"

    readonly property bool isModalHandoff: !ShellState.controlCenterOpen && (ShellState.isFloatingModalMode || ShellState.isModalMorphing) && ccCol.opacity > 0.005
    readonly property bool isOverlayActive: !ShellState.lockVisualOpen && (
        ShellState.controlCenterOpen
        || ShellState.mediaToastOpen
        || ccCol.opacity > 0.005
        || mediaToastLayer.opacity > 0.005
        || ShellState.isCcOrMediaMorph
    )
    onIsOverlayActiveChanged: ShellState.ccOverlayVisible = isOverlayActive

    // Keep an empty (0x0) region when collapsed or handing off to a modal so clicks pass straight through
    Item {
        id: panelContentMask
        x: panelContent.x
        y: panelContent.y
        width: (root.isOverlayActive && !ShellState.isFloatingModalMode && !ShellState.lockVisualOpen) ? panelContent.width : 0
        height: (root.isOverlayActive && !ShellState.isFloatingModalMode && !ShellState.lockVisualOpen) ? panelContent.height : 0
    }

    // Mask input exclusively to the live Center Dynamic Island bounds so toast/morph states never block the desktop
    mask: Region { item: panelContentMask }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-control-center"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: ShellState.controlCenterOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0

    // Pre-map the overlay surface while media plays (or is held paused) so hovering never stalls on Wayland surface creation
    visible: root.isOverlayActive || panelContent.opacity > 0.005 || ShellState.showMediaOnIsland

    HyprlandFocusGrab {
        active: ShellState.controlCenterOpen && root.isOverlayActive
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: {
            ShellState.controlCenterOpen = false;
        }
    }

    // Dismiss on Escape
    Item {
        focus: ShellState.controlCenterOpen
        Keys.onEscapePressed: {
            if (root.wifiPromptSsid.length > 0) {
                root.wifiPromptSsid = "";
                root.wifiErrorMsg = "";
            } else if (ShellState.networkExtended || ShellState.bluetoothExtended || ShellState.audioExtended) {
                ShellState.networkExtended = false;
                ShellState.bluetoothExtended = false;
                ShellState.audioExtended = false;
            } else {
                ShellState.controlCenterOpen = false;
            }
        }
    }

    // Bind PipeWire default sink & source so volume and mic controls work in real time
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var notifServer: ShellState.notifServer

    // ================= LIVE SUBMENU MODELS (AUDIO, NETWORK, BLUETOOTH) =================
    property string activeAudioTitle: "G733 Gaming Headset"
    property string activeAudioIcon: "󰋎"

    ListModel { id: audioSinksModel }
    ListModel { id: netItemsModel }
    ListModel { id: btItemsModel }

    function parseAndPopulateAudio(raw) {
        try {
            const arr = JSON.parse(raw.trim());
            audioSinksModel.clear();
            for (let i = 0; i < arr.length; i++) {
                const item = arr[i];
                audioSinksModel.append({
                    sinkId: Number(item.id || 0),
                    sinkName: String(item.name || ""),
                    title: String(item.title || "Audio Output"),
                    subtitle: String(item.subtitle || ""),
                    icon: String(item.icon || "󰓃"),
                    active: Boolean(item.active)
                });
                if (item.active) {
                    root.activeAudioTitle = String(item.title || "Audio Output");
                    root.activeAudioIcon = String(item.icon || "󰓃");
                }
            }
        } catch (e) {}
    }

    Process {
        id: audioListProc
        command: [ShellState.script("audio-manager.sh")]
        stdout: SplitParser {
            onRead: data => root.parseAndPopulateAudio(data)
        }
    }

    property string pendingSinkName: ""
    property string pendingSinkId: ""

    Process {
        id: audioSetProc
        command: [ShellState.script("audio-manager.sh"), "set", root.pendingSinkName, root.pendingSinkId]
        stdout: SplitParser {
            onRead: data => root.parseAndPopulateAudio(data)
        }
    }

    function selectAudioOutput(sinkName, sinkId) {
        root.pendingSinkName = String(sinkName);
        root.pendingSinkId = String(sinkId);
        audioSetProc.running = false;
        audioSetProc.running = true;
    }

    property string wifiTargetCmd: "toggle"
    property string btTargetCmd: "toggle"
    property bool wifiRadioActive: true
    property string wifiStatusText: "Connected"
    property bool btAdapterActive: true
    property string btStatusText: "On"

    property string netActionCmd: ""
    property string netActionTarget: ""
    property string netActionPassword: ""
    property string wifiPromptSsid: ""
    property string wifiErrorMsg: ""
    property bool wifiConnecting: false
    property bool wifiShowPassword: false

    function syncListModel(model, mapped) {
        let sameOrder = (model.count === mapped.length);
        if (sameOrder) {
            for (let i = 0; i < mapped.length; i++) {
                if (model.get(i).itemId !== mapped[i].itemId || model.get(i).itemType !== mapped[i].itemType) {
                    sameOrder = false;
                    break;
                }
            }
        }
        if (sameOrder) {
            for (let i = 0; i < mapped.length; i++) {
                const cur = model.get(i);
                const nxt = mapped[i];
                if (cur.title !== nxt.title) model.setProperty(i, "title", nxt.title);
                if (cur.subtitle !== nxt.subtitle) model.setProperty(i, "subtitle", nxt.subtitle);
                if (cur.icon !== nxt.icon) model.setProperty(i, "icon", nxt.icon);
                if (cur.statusText !== nxt.statusText) model.setProperty(i, "statusText", nxt.statusText);
                if (cur.active !== nxt.active) model.setProperty(i, "active", nxt.active);
                if (nxt.hasSecret !== undefined && cur.hasSecret !== nxt.hasSecret) model.setProperty(i, "hasSecret", nxt.hasSecret);
                if (nxt.security !== undefined && cur.security !== nxt.security) model.setProperty(i, "security", nxt.security);
            }
        } else {
            model.clear();
            for (let i = 0; i < mapped.length; i++) {
                model.append(mapped[i]);
            }
        }
    }

    function applyNetworkListJson(raw, fromAction) {
        try {
            const parsed = JSON.parse(String(raw || "").trim());
            const arr = Array.isArray(parsed) ? parsed : (parsed.items || []);
            const err = (!Array.isArray(parsed) && parsed.error) ? String(parsed.error) : "";
            const pwSsid = (!Array.isArray(parsed) && parsed.needsPasswordSsid) ? String(parsed.needsPasswordSsid) : "";
            let hasWifi = false;
            let wifiOn = false;
            let ethActive = false;
            let connectedSsid = "";
            let wifiHasIp = false;
            const mapped = [];
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                const t = String(it.type || "wifi");
                const act = Boolean(it.active);
                const sub = String(it.subtitle || "");
                if (t === "wifi") {
                    hasWifi = true;
                    wifiOn = act;
                    if (sub.indexOf("Connected") === 0 || (sub.indexOf("•") !== -1 && sub.indexOf("Disconnected") === -1 && sub.indexOf("Standby") === -1)) wifiHasIp = true;
                } else if (t === "ethernet" && act) {
                    ethActive = true;
                } else if (t === "ssid" && act && !connectedSsid) {
                    connectedSsid = String(it.title || "");
                }
                mapped.push({
                    itemId: String(it.id || ""),
                    title: String(it.title || "Network"),
                    subtitle: sub,
                    icon: String(it.icon || "󰤨"),
                    statusText: String(it.status || "Connect"),
                    active: act,
                    itemType: t,
                    security: String(it.security || ""),
                    hasSecret: it.hasSecret !== undefined ? Boolean(it.hasSecret) : true
                });
            }
            syncListModel(netItemsModel, mapped);
            root.wifiRadioActive = hasWifi ? wifiOn : ethActive;
            if (connectedSsid.length > 0) {
                root.wifiStatusText = connectedSsid;
            } else if (wifiHasIp) {
                root.wifiStatusText = "Connected";
            } else if (hasWifi && wifiOn) {
                root.wifiStatusText = ethActive ? "Ethernet • Wi-Fi On" : "Enabled";
            } else if (ethActive) {
                root.wifiStatusText = hasWifi ? "Ethernet • Wi-Fi Off" : "Connected";
            } else {
                root.wifiStatusText = "Off";
            }
            if (fromAction) {
                root.wifiConnecting = false;
                root.netActionPassword = "";
                if (pwSsid.length > 0) {
                    root.wifiPromptSsid = pwSsid;
                    root.wifiErrorMsg = err.length > 0 ? err : "Password required";
                } else if (err.length > 0) {
                    root.wifiErrorMsg = err;
                } else {
                    root.wifiPromptSsid = "";
                    root.wifiErrorMsg = "";
                }
            }
        } catch (e) {}
    }

    function applyBluetoothListJson(raw) {
        try {
            const arr = JSON.parse(String(raw || "").trim());
            let adapterOn = false;
            let hasAdapter = false;
            const connectedNames = [];
            const mapped = [];
            for (let i = 0; i < arr.length; i++) {
                const it = arr[i];
                const t = String(it.type || "device");
                const act = Boolean(it.active);
                if (t === "adapter") {
                    hasAdapter = true;
                    adapterOn = act;
                } else if (t === "device" && act) {
                    connectedNames.push(String(it.title || "Device"));
                }
                mapped.push({
                    itemId: String(it.id || ""),
                    title: String(it.title || "Bluetooth"),
                    subtitle: String(it.subtitle || ""),
                    icon: String(it.icon || "󰂯"),
                    statusText: String(it.status || "Connect"),
                    active: act,
                    itemType: t
                });
            }
            syncListModel(btItemsModel, mapped);
            root.btAdapterActive = hasAdapter ? adapterOn : false;
            if (!root.btAdapterActive) {
                root.btStatusText = "Off";
            } else if (connectedNames.length === 1) {
                root.btStatusText = connectedNames[0];
            } else if (connectedNames.length > 1) {
                root.btStatusText = connectedNames.length + " connected";
            } else {
                root.btStatusText = "On";
            }
        } catch (e) {}
    }

    Process {
        id: netActionProc
        command: root.netActionPassword.length > 0
            ? [ShellState.script("network-manager.sh"), root.netActionCmd, root.netActionTarget, root.netActionPassword]
            : [ShellState.script("network-manager.sh"), root.netActionCmd, root.netActionTarget]
        stdout: SplitParser {
            onRead: data => root.applyNetworkListJson(data, true)
        }
    }

    Timer {
        id: netRefreshTimer
        interval: 1100
        repeat: false
        onTriggered: {
            netListProc.running = false;
            netListProc.running = true;
        }
    }

    Timer {
        id: btRefreshTimer
        interval: 1100
        repeat: false
        onTriggered: {
            btListProc.running = false;
            btListProc.running = true;
        }
    }

    Process {
        id: netListProc
        command: [ShellState.script("network-manager.sh")]
        stdout: SplitParser {
            onRead: data => root.applyNetworkListJson(data)
        }
    }

    Process {
        id: btListProc
        command: [ShellState.script("bluetooth-manager.sh")]
        stdout: SplitParser {
            onRead: data => root.applyBluetoothListJson(data)
        }
    }

    Component.onCompleted: {
        ShellState.ccOverlayVisible = root.isOverlayActive;
        audioListProc.running = true;
        netListProc.running = true;
        btListProc.running = true;
    }

    DesktopCaptureSource {
        id: ccCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && panelContent.visible
    }

    // Aligned flush with ScreenFrame's Center Dynamic Island (fills the 42px-rounded island directly from y = Theme.barTopGap)
    Item {
        id: panelContent
        readonly property bool liquidGlassHost: true
        readonly property var liquidSource: ccCap.textureSource
        readonly property bool liquidSourceReady: ccCap.ready
        readonly property real liquidOriginX: (ShellState.mainScreenWidth - root.width) / 2
        readonly property real liquidOriginY: 0
        property int scrollTick: 0
        readonly property real liquidLayoutRev: ShellState.centerIslandWidth
            + ShellState.centerIslandHeight * 3.0
            + ShellState.islandDeformScaleX * 500.0
            + ShellState.islandDeformScaleY * 700.0
            + quickTabTrans.x * 1.13
            + quickMainTrans.x * 1.37
            + netSubTrans.x * 1.71
            + btSubTrans.x * 1.93
            + audioSubTrans.x * 2.11
            + mediaTabView.slideX * 2.33
            + activeTab * 11.0
            + scrollTick
            + (ShellState.networkExtended ? 17.0 : 0.0)
            + (ShellState.bluetoothExtended ? 23.0 : 0.0)
            + (ShellState.audioExtended ? 29.0 : 0.0)

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.isModalHandoff ? ShellState.centerIslandY : Theme.barTopGap
        width: root.panelWidth
        height: ShellState.centerIslandHeight
        clip: true
        opacity: 0.0
        // Hold overlay rendered briefly on return so Bar's Wayland surface never blinks blank between commits
        visible: root.isOverlayActive || opacity > 0.005

        BottomGlassWave {
            z: 20
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: ShellState.centerIslandRadius
            intensity: 1.0
            active: ShellState.liquidGlassEnabled && ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && ShellState.centerIslandHeight > Theme.barHeight + 2
                && (ShellState.controlCenterOpen || ShellState.centerIslandMode === "ccQuick" || ShellState.centerIslandMode === "ccMedia")
        }

        Component.onCompleted: opacity = root.isOverlayActive ? 1.0 : 0.0

        NumberAnimation {
            id: overlayHandoffOutAnim
            target: panelContent
            property: "opacity"
            to: 0.0
            duration: 36
            easing.type: Easing.Linear
        }

        Connections {
            target: root
            function onIsOverlayActiveChanged() {
                if (root.isOverlayActive) {
                    overlayHandoffOutAnim.stop();
                    panelContent.opacity = 1.0;
                } else {
                    overlayHandoffOutAnim.restart();
                }
            }
        }

        property int activeTab: ShellState.ccActiveTab

        // Refresh audio, network & bluetooth models cleanly whenever Control Center opens
        Connections {
            target: ShellState
            function onControlCenterOpenChanged() {
                if (ShellState.controlCenterOpen) {
                    audioListProc.running = true;
                    netListProc.running = true;
                    btListProc.running = true;
                } else {
                    root.wifiPromptSsid = "";
                    root.wifiErrorMsg = "";
                    root.wifiConnecting = false;
                }
            }
        }

        // Ambient slow glassy wave anchored inside ScreenFrame's Center Morphing Capsule
        // Unified Elastic Deformation Container:
        // Smoothly tracks the non-overshooting island target while deforming in 1:1 lockstep with the bouncing capsule!
        Item {
            id: islandDeformLayer
            width: ShellState.smoothCenterIslandWidth
            height: ShellState.smoothCenterIslandHeight
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0

            transform: Scale {
                origin.x: islandDeformLayer.width / 2
                origin.y: 0
                xScale: ShellState.islandDeformScaleX
                yScale: ShellState.islandDeformScaleY
            }

        // ================= 1. IN-BETWEEN "NOW PLAYING" TRACK CHANGE ANNOUNCEMENT LAYER =================
        Item {
            id: mediaToastLayer
            x: (parent.width - width) / 2
            y: 0
            width: ShellState.targetMediaToastWidth
            height: ShellState.targetMediaToastHeight
            opacity: ShellState.centerIslandMode === "mediaToast" ? 1.0 : 0.0
            visible: opacity > 0.005
            enabled: ShellState.mediaToastOpen && !ShellState.controlCenterOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: ShellState.centerIslandMode === "mediaToast" ? ShellState.animDur(320, 220) : ShellState.animDur(220, 120)
                    easing.type: ShellState.animPrimaryEase
                }
            }

            transform: Scale {
                origin.x: mediaToastLayer.width / 2
                origin.y: 0
                xScale: islandDeformLayer.width / Math.max(1, ShellState.targetMediaToastWidth)
                yScale: islandDeformLayer.height / Math.max(1, ShellState.targetMediaToastHeight)
            }

            Text {
                x: 80
                y: 16
                text: "NOW PLAYING"
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                font.letterSpacing: 0.9
                color: ShellState.mediaArtColor
            }

            // Hovering the Medium "Now Playing" Capsule keeps it open; ONLY clicking expands into the Full Media Panel
            HoverHandler {
                id: toastHover
                onHoveredChanged: {
                    if (hovered) {
                        ShellState.pauseMediaToastTimer();
                    } else {
                        ShellState.resumeMediaToastTimer();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    ShellState.mediaToastOpen = false;
                    ShellState.ccActiveTab = 1;
                    ShellState.controlCenterOpen = true;
                }
            }
        }

        // ================= 2. FULL CONTROL CENTER & MEDIA VIEW LAYER =================
        ColumnLayout {
            id: ccCol
            x: (parent.width - width) / 2
            y: 16
            width: Theme.ccMaxWidth - 40
            height: 408
            spacing: 10
            opacity: (ShellState.centerIslandMode === "ccQuick" || ShellState.centerIslandMode === "ccMedia") ? 1.0 : 0.0
            visible: opacity > 0.005
            enabled: ShellState.controlCenterOpen

            Behavior on opacity {
                NumberAnimation {
                    duration: (ShellState.isFloatingModalMode || ShellState.isModalMorphing || ShellState.lockVisualOpen || ShellState.kbOsdOpen) ? ShellState.animDur(140, 90) : ShellState.animDur(300, 240)
                    easing.type: ShellState.animPrimaryEase
                }
            }

            transform: Scale {
                origin.x: ccCol.width / 2
                origin.y: ccCol.height / 2
                xScale: Math.min(1.06, islandDeformLayer.width / Theme.ccMaxWidth)
                yScale: (ShellState.isFloatingModalMode || ShellState.isModalMorphing)
                    ? 1.0
                    : (0.72 + 0.28 * Math.min(1.0, Math.max(0.0, (islandDeformLayer.width - ShellState.centerIslandBaseWidth) / Math.max(1, Theme.ccMaxWidth - ShellState.centerIslandBaseWidth))))
            }

            // ================= TOP SEGMENTED TAB BAR (FROSTED GLASS PILL) =================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: 17
                color: tabTrackLg.isLiquidActive ? "transparent" : Theme.segmentedTrack
                border.width: tabTrackLg.isLiquidActive ? 0 : 1
                border.color: Theme.glassBorder

                LiquidGlassSurface {
                    id: tabTrackLg
                    anchors.fill: parent
                    z: -1
                    cornerRadius: 17
                }

                // Sliding active pill indicator
                Rectangle {
                    width: (parent.width - 6) / 2
                    height: parent.height - 6
                    y: 3
                    x: 3 + Math.min(1, panelContent.activeTab) * width
                    radius: 14
                    color: tabPillLg.isLiquidActive ? "transparent" : Theme.glassSurfaceActive
                    border.width: tabPillLg.isLiquidActive ? 0 : 1
                    border.color: Theme.glassBorder
                    onXChanged: tabPillLg.syncScreenBounds()

                    LiquidGlassSurface {
                        id: tabPillLg
                        anchors.fill: parent
                        z: -1
                        cornerRadius: 14
                        active: true
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: ShellState.animDur(360, 265)
                            easing.type: ShellState.animPrimaryEase
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 0

                    Repeater {
                        model: [
                            { icon: "󰒓", label: "Quick" },
                            { icon: "󰎈", label: "Media" }
                        ]

                        delegate: Item {
                            id: tabBtnItem
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            scale: tabMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 120 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: modelData.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    color: panelContent.activeTab === index ? Theme.text : Theme.textDim
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: panelContent.activeTab === index ? Font.Bold : Font.Medium
                                    color: panelContent.activeTab === index ? Theme.text : Theme.subtext
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.networkExtended = false;
                                    ShellState.bluetoothExtended = false;
                                    ShellState.audioExtended = false;
                                    ShellState.ccActiveTab = index;
                                }
                            }
                        }
                    }
                }
            }

            // ================= ANIMATED TAB VIEWS CONTAINER =================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // ================= TAB 0: QUICK SETTINGS (STRICT 174px / 82px MODULAR GRID) =================
                Item {
                    anchors.fill: parent
                    opacity: panelContent.activeTab === 0 ? 1.0 : 0.0
                    visible: opacity > 0.01
                    enabled: panelContent.activeTab === 0

                    transform: Translate {
                        id: quickTabTrans
                        x: panelContent.activeTab === 0 ? 0 : -16
                        Behavior on x { NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                    }
                    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(300, 220); easing.type: ShellState.animPrimaryEase } }

                    // ---------------- MAIN QUICK SETTINGS VIEW (3-BAND MODULAR BENTO GRID) ----------------
                    ColumnLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 10
                        opacity: (!ShellState.networkExtended && !ShellState.bluetoothExtended && !ShellState.audioExtended) ? 1.0 : 0.0
                        visible: opacity > 0.01
                        enabled: (!ShellState.networkExtended && !ShellState.bluetoothExtended && !ShellState.audioExtended)
                        transform: Translate {
                            id: quickMainTrans
                            x: (!ShellState.networkExtended && !ShellState.bluetoothExtended && !ShellState.audioExtended) ? 0 : -18
                            Behavior on x { NumberAnimation { duration: ShellState.animDur(360, 240); easing.type: ShellState.animPrimaryEase } }
                        }
                        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(280, 190); easing.type: ShellState.animPrimaryEase } }

                        // BAND 1 (124px): Connectivity Stack (Left) | Compact Now Playing (Right)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 124
                            Layout.maximumHeight: 124
                            spacing: 10

                            // Left Column (259x124): Network (57) + Gap (10) + Bluetooth (57)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 124
                                spacing: 10

                                // Wi-Fi / Network Card
                                GlassBox {
                                    id: wifiCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 57
                                    cornerRadius: 22
                                    active: root.wifiRadioActive
                                    hovered: wifiMouse.containsMouse
                                    pressed: wifiMouse.pressed

                                    MouseArea {
                                        id: wifiMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            netListProc.running = true;
                                            ShellState.networkExtended = true;
                                            ShellState.bluetoothExtended = false;
                                            ShellState.audioExtended = false;
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        z: 2

                                        GlassBadge {
                                            badgeSize: 32
                                            iconSize: 15
                                            active: root.wifiRadioActive
                                            hovered: wifiBadgeMouse.containsMouse
                                            pressed: wifiBadgeMouse.pressed
                                            icon: root.wifiRadioActive ? "󰤨" : "󰤭"

                                            MouseArea {
                                                id: wifiBadgeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const nextOn = !root.wifiRadioActive;
                                                    root.wifiTargetCmd = nextOn ? "on" : "off";
                                                    root.wifiRadioActive = nextOn;
                                                    root.wifiStatusText = nextOn ? "Enabling..." : "Off";
                                                    wifiToggleProc.running = false;
                                                    wifiToggleProc.running = true;
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "Wi-Fi"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.text
                                            }

                                            Text {
                                                text: root.wifiStatusText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                color: Theme.subtext
                                            }
                                        }

                                        Text {
                                            text: "󰅂"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 14
                                            color: Theme.textDim
                                        }
                                    }

                                    Process {
                                        id: wifiToggleProc
                                        command: [ShellState.script("network-manager.sh"), root.wifiTargetCmd]
                                        stdout: SplitParser {
                                            onRead: data => root.applyNetworkListJson(data)
                                        }
                                    }
                                }

                                // Bluetooth Card
                                GlassBox {
                                    id: btCard
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 57
                                    cornerRadius: 22
                                    active: root.btAdapterActive
                                    hovered: btMouse.containsMouse
                                    pressed: btMouse.pressed

                                    MouseArea {
                                        id: btMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            btListProc.running = true;
                                            ShellState.bluetoothExtended = true;
                                            ShellState.networkExtended = false;
                                            ShellState.audioExtended = false;
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        z: 2

                                        GlassBadge {
                                            badgeSize: 32
                                            iconSize: 15
                                            active: root.btAdapterActive
                                            hovered: btBadgeMouse.containsMouse
                                            pressed: btBadgeMouse.pressed
                                            icon: root.btAdapterActive ? "󰂯" : "󰂲"

                                            MouseArea {
                                                id: btBadgeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const nextOn = !root.btAdapterActive;
                                                    root.btTargetCmd = nextOn ? "on" : "off";
                                                    root.btAdapterActive = nextOn;
                                                    root.btStatusText = nextOn ? "Turning on..." : "Off";
                                                    btToggleProc.running = false;
                                                    btToggleProc.running = true;
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "Bluetooth"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                color: Theme.text
                                            }

                                            Text {
                                                text: root.btStatusText
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                                color: Theme.subtext
                                            }
                                        }

                                        Text {
                                            text: "󰅂"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 14
                                            color: Theme.textDim
                                        }
                                    }

                                    Process {
                                        id: btToggleProc
                                        command: [ShellState.script("bluetooth-manager.sh"), root.btTargetCmd]
                                        stdout: SplitParser {
                                            onRead: data => root.applyBluetoothListJson(data)
                                        }
                                    }
                                }
                            }

                            // Right Column (259x124): Balanced Mini Media Player Card
                            GlassBox {
                                id: miniMediaCard
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 124
                                cornerRadius: 24
                                hovered: miniMediaMouse.containsMouse
                                pressed: miniMediaMouse.pressed
                                clip: true

                                readonly property var mPlayer: root.mprisPlayer
                                readonly property bool isPlaying: mPlayer ? mPlayer.playbackState === MprisPlaybackState.Playing : false
                                readonly property real trackLength: (mPlayer && mPlayer.length > 0) ? (mPlayer.length > 100000 ? mPlayer.length / 1000000 : mPlayer.length) : 0
                                readonly property real trackPos: (mPlayer && mPlayer.position > 0) ? (mPlayer.position > 100000 ? mPlayer.position / 1000000 : mPlayer.position) : 0
                                readonly property real progress: trackLength > 0 ? Math.min(1.0, Math.max(0.0, trackPos / trackLength)) : 0.0
                                readonly property string artistText: {
                                    if (!mPlayer) return "Tap to open player";
                                    if (mPlayer.trackArtist && String(mPlayer.trackArtist).length > 0) return String(mPlayer.trackArtist);
                                    if (mPlayer.trackArtists) return String(mPlayer.trackArtists);
                                    if (mPlayer.identity) return String(mPlayer.identity);
                                    return "Media";
                                }

                                // Card background click -> switch to Media Tab
                                MouseArea {
                                    id: miniMediaMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.ccActiveTab = 1
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    z: 2

                                    // Top Row: Album Art (50x50) + Track Title/Artist
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        spacing: 10

                                        // 50x50 Spacer for Persistent Floating Album Art
                                        Item {
                                            Layout.preferredWidth: 50
                                            Layout.preferredHeight: 50
                                        }

                                        // Spacer for Persistent Floating Track Title & Artist
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                        }

                                        Text {
                                            text: "󰅂"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: Theme.textDim
                                        }
                                    }

                                    // Neutral Crisp Frosted Progress Bar
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 3
                                        radius: 1.5
                                        color: Theme.sliderTrack
                                        clip: true

                                        Rectangle {
                                            height: parent.height
                                            width: miniMediaCard.trackLength > 0 ? Math.max(3, parent.width * miniMediaCard.progress) : 0
                                            radius: 1.5
                                            color: Theme.sliderFill
                                            Behavior on width { NumberAnimation { duration: 150 } }
                                        }
                                    }

                                    // Compact Centered Transport Controls
                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 12

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: miniPrevLg.isLiquidActive ? "transparent" : (prevMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                                            border.color: prevMouse.containsMouse ? Theme.glassHighlight : Theme.glassBorder
                                            border.width: miniPrevLg.isLiquidActive ? 0 : 1
                                            scale: prevMouse.pressed ? 0.90 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            LiquidGlassSurface {
                                                id: miniPrevLg
                                                anchors.fill: parent
                                                z: -1
                                                cornerRadius: 14
                                                hovered: prevMouse.containsMouse
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒮"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: Theme.text
                                            }

                                            MouseArea {
                                                id: prevMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (miniMediaCard.mPlayer) miniMediaCard.mPlayer.previous()
                                            }
                                        }

                                        Rectangle {
                                            width: 32
                                            height: 32
                                            radius: 16
                                            color: (miniPlayLg.isLiquidActive && !miniMediaCard.isPlaying)
                                                ? "transparent"
                                                : (miniMediaCard.isPlaying ? Theme.sliderFill : (playMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard))
                                            border.color: (miniMediaCard.isPlaying || miniPlayLg.isLiquidActive) ? "transparent" : (playMouse.containsMouse ? Theme.glassHighlight : Theme.glassBorder)
                                            border.width: (miniMediaCard.isPlaying || miniPlayLg.isLiquidActive) ? 0 : 1
                                            scale: playMouse.pressed ? 0.90 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                            Behavior on color { ColorAnimation { duration: 140 } }

                                            LiquidGlassSurface {
                                                id: miniPlayLg
                                                anchors.fill: parent
                                                z: -1
                                                cornerRadius: 16
                                                visible: !miniMediaCard.isPlaying
                                                hovered: playMouse.containsMouse
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: miniMediaCard.isPlaying ? "󰏤" : "󰐊"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 16
                                                color: miniMediaCard.isPlaying ? Theme.sliderFillFg : Theme.text
                                            }

                                            MouseArea {
                                                id: playMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (miniMediaCard.mPlayer) miniMediaCard.mPlayer.togglePlaying()
                                            }
                                        }

                                        Rectangle {
                                            width: 28
                                            height: 28
                                            radius: 14
                                            color: miniNextLg.isLiquidActive ? "transparent" : (nextMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                                            border.color: nextMouse.containsMouse ? Theme.glassHighlight : Theme.glassBorder
                                            border.width: miniNextLg.isLiquidActive ? 0 : 1
                                            scale: nextMouse.pressed ? 0.90 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            LiquidGlassSurface {
                                                id: miniNextLg
                                                anchors.fill: parent
                                                z: -1
                                                cornerRadius: 14
                                                hovered: nextMouse.containsMouse
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰒭"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: Theme.text
                                            }

                                            MouseArea {
                                                id: nextMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (miniMediaCard.mPlayer) miniMediaCard.mPlayer.next()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // BAND 2 (118px): Audio/Display Sliders (Left) | 2x2 Quick Toggles (Right)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 118
                            Layout.maximumHeight: 118
                            spacing: 10

                            // Left Column (259x118): Volume + Brightness + Audio Output
                            GlassBox {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 118
                                cornerRadius: 24

                                readonly property var sinkNode: Pipewire.defaultAudioSink
                                readonly property real vol: (sinkNode && sinkNode.audio && !isNaN(sinkNode.audio.volume)) ? Math.min(1.0, Math.max(0.0, sinkNode.audio.volume)) : 0.5
                                readonly property bool isMuted: (sinkNode && sinkNode.audio) ? sinkNode.audio.muted : false

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    // Volume Slider Pill (28px)
                                    Rectangle {
                                        id: volTrack
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Theme.sliderTrack
                                        border.color: Theme.glassBorder
                                        border.width: 1
                                        clip: true

                                        readonly property real activeVol: parent.parent.isMuted ? 0 : parent.parent.vol

                                        Rectangle {
                                            id: volFill
                                            height: parent.height
                                            width: volTrack.activeVol > 0.01 ? Math.max(parent.height, parent.width * volTrack.activeVol) : 0
                                            radius: 14
                                            color: Theme.sliderFill

                                            Behavior on width {
                                                enabled: !volMouse.pressed
                                                NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        Text {
                                            x: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            z: 3
                                            text: parent.parent.parent.isMuted ? "󰝟" : (parent.parent.parent.vol < 0.33 ? "󰕿" : (parent.parent.parent.vol < 0.66 ? "󰖀" : "󰕾"))
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: volFill.width >= 26 ? Theme.sliderFillFg : Theme.text
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            z: 3
                                            text: parent.parent.parent.isMuted ? "Muted" : (Math.round(parent.parent.parent.vol * 100) + "%")
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            font.features: { "tnum": 1 }
                                            color: volFill.width >= parent.width - 34 ? Theme.sliderFillFg : Theme.subtext
                                        }

                                        MouseArea {
                                            id: volMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor

                                            function updateVolume(mx) {
                                                const r = Math.max(0.0, Math.min(1.0, mx / width));
                                                const s = Pipewire.defaultAudioSink;
                                                if (s && s.audio) {
                                                    s.audio.volume = r;
                                                    if (s.audio.muted) s.audio.muted = false;
                                                }
                                            }

                                            onPressed: mouse => updateVolume(mouse.x)
                                            onPositionChanged: mouse => { if (pressed) updateVolume(mouse.x); }
                                        }
                                    }

                                    // Brightness Slider Pill (28px)
                                    Rectangle {
                                        id: brightTrack
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: Theme.sliderTrack
                                        border.color: Theme.glassBorder
                                        border.width: 1
                                        clip: true

                                        Rectangle {
                                            id: brightFill
                                            height: parent.height
                                            width: Math.max(parent.height, parent.width * ShellState.brightness)
                                            radius: 14
                                            color: Theme.sliderFill

                                            Behavior on width {
                                                enabled: !brightMouse.pressed
                                                NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
                                            }
                                        }

                                        Text {
                                            x: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            z: 3
                                            text: "󰃠"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: brightFill.width >= 26 ? Theme.sliderFillFg : Theme.text
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            z: 3
                                            text: Math.round(ShellState.brightness * 100) + "%"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            font.features: { "tnum": 1 }
                                            color: brightFill.width >= parent.width - 34 ? Theme.sliderFillFg : Theme.subtext
                                        }

                                        MouseArea {
                                            id: brightMouse
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor

                                            function updateBrightness(mx, immediate) {
                                                const r = Math.max(0.15, Math.min(1.0, mx / width));
                                                ShellState.setBrightness(r, immediate);
                                            }

                                            onPressed: mouse => updateBrightness(mouse.x, false)
                                            onPositionChanged: mouse => { if (pressed) updateBrightness(mouse.x, false); }
                                            onReleased: ShellState.setBrightness(ShellState.brightness, true)
                                        }
                                    }

                                    // Audio Output Selector Bar (26px)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        radius: 10
                                        color: audioOutRowMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                                        scale: audioOutRowMouse.pressed ? 0.97 : 1.0
                                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase } }
                                        Behavior on color { ColorAnimation { duration: ShellState.animDur(180, 120) } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 4
                                            anchors.rightMargin: 4
                                            spacing: 8

                                            Rectangle {
                                                implicitWidth: 22
                                                implicitHeight: 22
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 11
                                                color: Theme.glassSurfaceHover
                                                border.width: 1
                                                border.color: Theme.glassBorder

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.activeAudioIcon
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: 11
                                                    color: Theme.text
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.activeAudioTitle
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                color: Theme.text
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: "Output"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                color: Theme.textDim
                                            }

                                            Text {
                                                text: "󰅂"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 13
                                                color: Theme.subtext
                                            }
                                        }

                                        MouseArea {
                                            id: audioOutRowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                audioListProc.running = true;
                                                ShellState.audioExtended = true;
                                                ShellState.networkExtended = false;
                                                ShellState.bluetoothExtended = false;
                                            }
                                        }
                                    }
                                }
                            }

                            // Right Column (259x118): Uniform 2x2 Quick Toggle Tiles (4 identical 124.5x54 cards)
                            GridLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 118
                                columns: 2
                                columnSpacing: 10
                                rowSpacing: 10

                                // Toggle 1: Microphone
                                GlassBox {
                                    id: qMicCard
                                    property var micNode: Pipewire.defaultAudioSource
                                    property bool isMuted: (micNode && micNode.audio) ? micNode.audio.muted : false
                                    onIsMutedChanged: if (ccCol.visible) qMicAnim.restart()
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 0
                                    cornerRadius: 22
                                    active: !isMuted
                                    hovered: qMicMouse.containsMouse
                                    pressed: qMicMouse.pressed

                                    SequentialAnimation {
                                        id: qMicAnim
                                        ParallelAnimation {
                                            NumberAnimation { target: qMicIcon; property: "scale"; to: 1.24; duration: ShellState.animDur(130, 85); easing.type: Easing.OutCubic }
                                            NumberAnimation { target: qMicIcon; property: "rotation"; to: qMicCard.isMuted ? -14 : 10; duration: ShellState.animDur(120, 80); easing.type: Easing.OutCubic }
                                        }
                                        ParallelAnimation {
                                            NumberAnimation { target: qMicIcon; property: "scale"; to: 1.0; duration: ShellState.animDur(180, 120); easing.type: ShellState.animPrimaryEase }
                                            NumberAnimation { target: qMicIcon; property: "rotation"; to: 0; duration: ShellState.animDur(180, 120); easing.type: ShellState.animPrimaryEase }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            radius: 14
                                            color: qMicCard.active ? Theme.sliderFill : Theme.glassCard
                                            border.width: qMicCard.active ? 0 : 1
                                            border.color: Theme.glassBorder
                                            scale: qMicMouse.pressed ? 0.90 : (qMicMouse.containsMouse ? 1.06 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(170, 115); easing.type: ShellState.animPrimaryEase } }
                                            Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(220, 150) } }

                                            Text {
                                                id: qMicIcon
                                                anchors.centerIn: parent
                                                text: qMicCard.isMuted ? "󰍭" : "󰍬"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: qMicCard.active ? Theme.sliderFillFg : Theme.textDim
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "Mic"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: qMicCard.active ? Theme.text : Theme.subtext
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                                            }

                                            Text {
                                                text: qMicCard.isMuted ? "Muted" : "Active"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: qMicCard.active ? Theme.subtext : Theme.textDim
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: qMicMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (qMicCard.micNode && qMicCard.micNode.audio) {
                                                qMicCard.micNode.audio.muted = !qMicCard.micNode.audio.muted;
                                            }
                                        }
                                    }
                                }

                                // Toggle 2: Keep Awake / Caffeine
                                GlassBox {
                                    id: qAwakeCard
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 0
                                    cornerRadius: 22
                                    active: ShellState.awakeActive
                                    hovered: qAwakeMouse.containsMouse
                                    pressed: qAwakeMouse.pressed

                                    Connections {
                                        target: ShellState
                                        function onAwakeActiveChanged() {
                                            if (ccCol.visible) qAwakeAnim.restart();
                                        }
                                    }

                                    SequentialAnimation {
                                        id: qAwakeAnim
                                        ParallelAnimation {
                                            NumberAnimation { target: qAwakeIcon; property: "scale"; to: 1.24; duration: ShellState.animDur(130, 85); easing.type: Easing.OutCubic }
                                            NumberAnimation { target: qAwakeIcon; property: "rotation"; to: -14; duration: ShellState.animDur(110, 75); easing.type: Easing.OutCubic }
                                        }
                                        NumberAnimation { target: qAwakeIcon; property: "rotation"; to: 8; duration: ShellState.animDur(110, 75); easing.type: Easing.InOutCubic }
                                        ParallelAnimation {
                                            NumberAnimation { target: qAwakeIcon; property: "scale"; to: 1.0; duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase }
                                            NumberAnimation { target: qAwakeIcon; property: "rotation"; to: 0; duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            radius: 14
                                            color: qAwakeCard.active ? Theme.sliderFill : Theme.glassCard
                                            border.width: qAwakeCard.active ? 0 : 1
                                            border.color: Theme.glassBorder
                                            scale: qAwakeMouse.pressed ? 0.90 : (qAwakeMouse.containsMouse ? 1.06 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(170, 115); easing.type: ShellState.animPrimaryEase } }
                                            Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(220, 150) } }

                                            Text {
                                                id: qAwakeIcon
                                                anchors.centerIn: parent
                                                text: "󰅶"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: qAwakeCard.active ? Theme.sliderFillFg : Theme.textDim
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "Awake"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: qAwakeCard.active ? Theme.text : Theme.subtext
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                                            }

                                            Text {
                                                text: qAwakeCard.active ? "On" : "Off"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: qAwakeCard.active ? Theme.subtext : Theme.textDim
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: qAwakeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ShellState.awakeActive = !ShellState.awakeActive
                                    }
                                }

                                // Toggle 3: Do Not Disturb
                                GlassBox {
                                    id: qDndCard
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 0
                                    cornerRadius: 22
                                    active: ShellState.dndActive
                                    hovered: qDndMouse.containsMouse
                                    pressed: qDndMouse.pressed

                                    Connections {
                                        target: ShellState
                                        function onDndActiveChanged() {
                                            if (ccCol.visible) qDndAnim.restart();
                                        }
                                    }

                                    SequentialAnimation {
                                        id: qDndAnim
                                        ParallelAnimation {
                                            NumberAnimation { target: qDndIcon; property: "scale"; to: 1.24; duration: ShellState.animDur(120, 80); easing.type: Easing.OutCubic }
                                            NumberAnimation { target: qDndIcon; property: "rotation"; to: -18; duration: ShellState.animDur(100, 70); easing.type: Easing.OutCubic }
                                        }
                                        NumberAnimation { target: qDndIcon; property: "rotation"; to: 14; duration: ShellState.animDur(110, 75); easing.type: Easing.InOutCubic }
                                        ParallelAnimation {
                                            NumberAnimation { target: qDndIcon; property: "rotation"; to: 0; duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase }
                                            NumberAnimation { target: qDndIcon; property: "scale"; to: 1.0; duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            radius: 14
                                            color: qDndCard.active ? Theme.sliderFill : Theme.glassCard
                                            border.width: qDndCard.active ? 0 : 1
                                            border.color: Theme.glassBorder
                                            scale: qDndMouse.pressed ? 0.90 : (qDndMouse.containsMouse ? 1.06 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(170, 115); easing.type: ShellState.animPrimaryEase } }
                                            Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(220, 150) } }

                                            Text {
                                                id: qDndIcon
                                                anchors.centerIn: parent
                                                text: ShellState.dndActive ? "󰂛" : "󰂚"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: qDndCard.active ? Theme.sliderFillFg : Theme.textDim
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "DND"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: qDndCard.active ? Theme.text : Theme.subtext
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                                            }

                                            Text {
                                                text: ShellState.dndActive ? "On" : "Off"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: qDndCard.active ? Theme.subtext : Theme.textDim
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(200, 140) } }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: qDndMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ShellState.dndActive = !ShellState.dndActive
                                    }
                                }

                                // Toggle 4: Dark / Light Mode Switcher
                                GlassBox {
                                    id: qThemeModeCard
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 0
                                    Layout.preferredHeight: 0
                                    cornerRadius: 22
                                    active: Theme.lightMode && !ShellState.liquidGlassEnabled
                                    hovered: !ShellState.liquidGlassEnabled && qThemeModeMouse.containsMouse
                                    pressed: !ShellState.liquidGlassEnabled && qThemeModeMouse.pressed
                                    opacity: ShellState.liquidGlassEnabled ? 0.48 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8

                                        Rectangle {
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            radius: 14
                                            color: qThemeModeCard.active ? Theme.sliderFill : Theme.glassCard
                                            border.width: qThemeModeCard.active ? 0 : 1
                                            border.color: Theme.glassBorder
                                            scale: (!ShellState.liquidGlassEnabled && qThemeModeMouse.pressed) ? 0.90 : ((!ShellState.liquidGlassEnabled && qThemeModeMouse.containsMouse) ? 1.06 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(170, 115); easing.type: ShellState.animPrimaryEase } }
                                            Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                            Behavior on border.color { ColorAnimation { duration: ShellState.animDur(220, 150) } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.lightMode ? "󰖙" : "󰖔"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 14
                                                color: qThemeModeCard.active ? Theme.sliderFillFg : Theme.text
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
                                                rotation: Theme.lightMode ? 180 : 0
                                                Behavior on rotation {
                                                    NumberAnimation { duration: ShellState.animDur(360, 260); easing.type: ShellState.animPrimaryEase }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                text: "Theme"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: Theme.text
                                            }

                                            Text {
                                                text: ShellState.liquidGlassEnabled ? "Glass Lock" : (Theme.lightMode ? "Light" : "Dark")
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 10
                                                color: Theme.subtext
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: qThemeModeMouse
                                        anchors.fill: parent
                                        enabled: !ShellState.liquidGlassEnabled
                                        hoverEnabled: !ShellState.liquidGlassEnabled
                                        cursorShape: ShellState.liquidGlassEnabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        onClicked: ShellState.toggleThemeMode()
                                    }
                                }
                            }
                        }

                        // BAND 3 (40px): 5 Equal Full-Width Pill Utility Buttons
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            Layout.maximumHeight: 40
                            spacing: 10

                            GlassBox {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 40
                                cornerRadius: 20
                                hovered: shotRegionMouse.containsMouse
                                pressed: shotRegionMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰹑"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: Theme.text
                                    }

                                    Text {
                                        text: "Region"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: shotRegionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ShellState.controlCenterOpen = false;
                                        Quickshell.execDetached([ShellState.script("screenshot.sh"), "--region", "--delay"]);
                                    }
                                }
                            }

                            GlassBox {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 40
                                cornerRadius: 20
                                hovered: shotFullMouse.containsMouse
                                pressed: shotFullMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰄀"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: Theme.text
                                    }

                                    Text {
                                        text: "Screen"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: shotFullMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ShellState.controlCenterOpen = false;
                                        Quickshell.execDetached([ShellState.script("screenshot.sh"), "--fullscreen", "--delay"]);
                                    }
                                }
                            }

                            GlassBox {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 40
                                cornerRadius: 20
                                active: ShellState.settingsOpen
                                hovered: settingsBtnMouse.containsMouse
                                pressed: settingsBtnMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰒓"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 13
                                        color: Theme.text
                                    }

                                    Text {
                                        text: "Settings"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: settingsBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.toggleSettings()
                                }
                            }

                            GlassBox {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 40
                                cornerRadius: 20
                                active: ShellState.cheatSheetOpen
                                hovered: cheatBtnMouse.containsMouse
                                pressed: cheatBtnMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰌌"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 13
                                        color: Theme.text
                                    }

                                    Text {
                                        text: "Shortcuts"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: cheatBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.toggleCheatSheet()
                                }
                            }

                            GlassBox {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                                Layout.preferredHeight: 40
                                cornerRadius: 20
                                active: ShellState.powerOsdOpen
                                hovered: pwrMouse.containsMouse
                                pressed: pwrMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: "󰐥"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 14
                                        color: Theme.text
                                    }

                                    Text {
                                        text: "Power"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: pwrMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.togglePowerOsd()
                                }
                            }
                        }
                    }

                    // ---------------- NETWORK EXTENDED SUB-PAGE ----------------
                    ColumnLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 364
                        spacing: 10
                        opacity: ShellState.networkExtended ? 1.0 : 0.0
                        visible: opacity > 0.01
                        enabled: ShellState.networkExtended
                        transform: Translate {
                            id: netSubTrans
                            x: ShellState.networkExtended ? 0 : 18
                            Behavior on x { NumberAnimation { duration: ShellState.animDur(360, 240); easing.type: ShellState.animPrimaryEase } }
                        }
                        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(280, 190); easing.type: ShellState.animPrimaryEase } }

                        // Consistent Submenu Header Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: 10

                            GlassBox {
                                implicitWidth: 34
                                implicitHeight: 34
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                cornerRadius: 17
                                hovered: netBackMouse.containsMouse
                                pressed: netBackMouse.pressed

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅁"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 16
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: netBackMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.networkExtended = false
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Network & Wi-Fi"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            GlassBox {
                                implicitWidth: 78
                                implicitHeight: 30
                                Layout.preferredWidth: 78
                                Layout.preferredHeight: 30
                                cornerRadius: 15
                                hovered: netRefreshMouse.containsMouse
                                pressed: netRefreshMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "󰑐"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                        color: Theme.text
                                    }
                                    Text {
                                        text: "Refresh"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: netRefreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached([ShellState.script("network-manager.sh"), "rescan"]);
                                        netListProc.running = false;
                                        netListProc.running = true;
                                        netRefreshTimer.restart();
                                    }
                                }
                            }
                        }

                        // Inline Wi-Fi Password Prompt (shown when connecting to a secured SSID without a saved secret)
                        GlassBox {
                            id: wifiPasswordCard
                            readonly property bool showCard: root.wifiPromptSsid.length > 0 || root.wifiErrorMsg.length > 0
                            readonly property real targetH: root.wifiPromptSsid.length > 0 ? (root.wifiErrorMsg.length > 0 ? 104 : 84) : (root.wifiErrorMsg.length > 0 ? 34 : 0)
                            property string displaySsid: ""
                            Connections {
                                target: root
                                function onWifiPromptSsidChanged() {
                                    if (root.wifiPromptSsid.length > 0) wifiPasswordCard.displaySsid = root.wifiPromptSsid;
                                }
                            }
                            Layout.fillWidth: true
                            Layout.preferredHeight: targetH
                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            opacity: showCard ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.InOutCubic } }
                            visible: Layout.preferredHeight > 0.5 || opacity > 0.005
                            clip: true
                            cornerRadius: 16
                            active: root.wifiPromptSsid.length > 0

                            function submitWifiPassword() {
                                if (root.wifiPromptSsid.length === 0) return;
                                root.wifiConnecting = true;
                                root.wifiErrorMsg = "";
                                root.netActionCmd = "connect";
                                root.netActionTarget = root.wifiPromptSsid;
                                root.netActionPassword = wifiPasswordInput.text;
                                netActionProc.running = false;
                                netActionProc.running = true;
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 6

                                transform: Translate {
                                    y: wifiPasswordCard.showCard ? 0 : -6
                                    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: wifiPasswordCard.displaySsid.length > 0 && (root.wifiPromptSsid.length > 0 || wifiPasswordCard.opacity > 0.005)
                                    spacing: 8

                                    Text {
                                        text: "󰤪"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Password for " + wifiPasswordCard.displaySsid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: Theme.text
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: netPwCloseMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                                        scale: netPwCloseMouse.pressed ? 0.88 : (netPwCloseMouse.containsMouse ? 1.08 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                                        Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: netPwCloseMouse.containsMouse ? Theme.text : Theme.subtext
                                            Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                                        }

                                        MouseArea {
                                            id: netPwCloseMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.wifiPromptSsid = "";
                                                root.wifiErrorMsg = "";
                                                wifiPasswordInput.text = "";
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: wifiPasswordCard.displaySsid.length > 0 && (root.wifiPromptSsid.length > 0 || wifiPasswordCard.opacity > 0.005)
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 10
                                        color: Theme.glassCard
                                        border.width: 1
                                        border.color: wifiPasswordInput.activeFocus ? Theme.accent : Theme.glassBorder

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            TextInput {
                                                id: wifiPasswordInput
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 11
                                                color: Theme.text
                                                selectionColor: Theme.accent
                                                echoMode: root.wifiShowPassword ? TextInput.Normal : TextInput.Password
                                                clip: true
                                                Keys.onReturnPressed: wifiPasswordCard.submitWifiPassword()
                                                Keys.onEnterPressed: wifiPasswordCard.submitWifiPassword()

                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "Enter Wi-Fi password..."
                                                    font: parent.font
                                                    color: Theme.textDim
                                                    visible: parent.text.length === 0
                                                }
                                            }

                                            Rectangle {
                                                width: 22
                                                height: 22
                                                radius: 11
                                                color: netPwEyeMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                                                scale: netPwEyeMouse.pressed ? 0.88 : (netPwEyeMouse.containsMouse ? 1.08 : 1.0)
                                                Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                                                Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.wifiShowPassword ? "󰈈" : "󰈉"
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: 13
                                                    color: netPwEyeMouse.containsMouse ? Theme.text : Theme.subtext
                                                    Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                                                }

                                                MouseArea {
                                                    id: netPwEyeMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.wifiShowPassword = !root.wifiShowPassword
                                                }
                                            }
                                        }
                                    }

                                    GlassBox {
                                        implicitWidth: 74
                                        implicitHeight: 30
                                        Layout.preferredWidth: 74
                                        Layout.preferredHeight: 30
                                        cornerRadius: 10
                                        active: true
                                        hovered: wifiJoinMouse.containsMouse
                                        pressed: wifiJoinMouse.pressed

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.wifiConnecting ? "Joining..." : "Connect"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: Theme.text
                                        }

                                        MouseArea {
                                            id: wifiJoinMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wifiPasswordCard.submitWifiPassword()
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.wifiErrorMsg.length > 0
                                    text: root.wifiErrorMsg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: "#F87171"
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Scrollable Network Interfaces & Connections List (with smooth fade-out)
                        ListView {
                            id: netSubListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            topMargin: 4
                            bottomMargin: 14
                            model: netItemsModel
                            boundsBehavior: Flickable.StopAtBounds

                            property real scrollTargetY: 0
                            readonly property real topFade: Math.min(1.0, Math.max(0.0, contentY / 14.0))
                            readonly property real botFade: Math.min(1.0, Math.max(0.0, (contentHeight - height - contentY) / 14.0))

                            Behavior on contentY {
                                NumberAnimation { duration: 105; easing.type: Easing.OutCubic }
                            }

                            WheelHandler {
                                target: null
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    const maxContentY = Math.max(0, netSubListView.contentHeight - netSubListView.height);
                                    const delta = event.angleDelta.y;
                                    const step = (delta !== 0 ? (delta / 120.0) : (event.pixelDelta.y / 18.0)) * 110;
                                    netSubListView.scrollTargetY = Math.max(0, Math.min(maxContentY, netSubListView.scrollTargetY - step));
                                    netSubListView.contentY = netSubListView.scrollTargetY;
                                    event.accepted = true;
                                }
                            }

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Item {
                                    width: Math.max(1, netSubListView.width)
                                    height: Math.max(1, netSubListView.height)

                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0 - netSubListView.topFade) }
                                            GradientStop { position: 0.02; color: Qt.rgba(1, 1, 1, 1.0 - netSubListView.topFade) }
                                            GradientStop { position: 0.06; color: Qt.rgba(1, 1, 1, 1.0 - 0.65 * netSubListView.topFade) }
                                            GradientStop { position: 0.11; color: "#ffffffff" }
                                            GradientStop { position: 0.87; color: "#ffffffff" }
                                            GradientStop { position: 0.93; color: Qt.rgba(1, 1, 1, 1.0 - 0.68 * netSubListView.botFade) }
                                            GradientStop { position: 0.98; color: Qt.rgba(1, 1, 1, 1.0 - netSubListView.botFade) }
                                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.0 - netSubListView.botFade) }
                                        }
                                    }
                                }
                            }

                            delegate: GlassBox {
                                id: netItemCard
                                required property var model
                                required property int index
                                width: netSubListView.width
                                height: 64
                                cornerRadius: 16
                                active: model.active
                                hovered: netItemMouse.containsMouse
                                pressed: netItemMouse.pressed

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    GlassBadge {
                                        badgeSize: 38
                                        iconSize: 18
                                        active: netItemCard.model.active
                                        icon: netItemCard.model.icon
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: netItemCard.model.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: Theme.text
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: netItemCard.model.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.subtext
                                            elide: Text.ElideRight
                                        }
                                    }

                                    GlassBox {
                                        implicitWidth: 78
                                        implicitHeight: 28
                                        Layout.preferredWidth: 78
                                        Layout.preferredHeight: 28
                                        cornerRadius: 14
                                        active: netItemCard.model.active
                                        hovered: netItemMouse.containsMouse

                                        Text {
                                            anchors.centerIn: parent
                                            text: netItemCard.model.statusText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: Theme.text
                                        }
                                    }
                                }

                                MouseArea {
                                    id: netItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (netItemCard.model.itemType === "ssid") {
                                            if (netItemCard.model.active) {
                                                root.netActionCmd = "disconnect";
                                                root.netActionTarget = netItemCard.model.itemId;
                                                root.netActionPassword = "";
                                                netItemsModel.setProperty(netItemCard.index, "statusText", "Disconnecting...");
                                                netActionProc.running = false;
                                                netActionProc.running = true;
                                            } else if (!netItemCard.model.hasSecret) {
                                                root.wifiErrorMsg = "";
                                                root.wifiPromptSsid = netItemCard.model.itemId;
                                                wifiPasswordInput.text = "";
                                                wifiPasswordInput.forceActiveFocus();
                                            } else {
                                                root.wifiErrorMsg = "";
                                                root.wifiPromptSsid = "";
                                                root.wifiConnecting = true;
                                                root.netActionCmd = "connect";
                                                root.netActionTarget = netItemCard.model.itemId;
                                                root.netActionPassword = "";
                                                netItemsModel.setProperty(netItemCard.index, "statusText", "Connecting...");
                                                netActionProc.running = false;
                                                netActionProc.running = true;
                                            }
                                        } else if (netItemCard.model.itemType === "wifi") {
                                            const nextOn = !root.wifiRadioActive;
                                            root.wifiTargetCmd = nextOn ? "on" : "off";
                                            root.wifiRadioActive = nextOn;
                                            root.wifiStatusText = nextOn ? "Enabling..." : "Off";
                                            netItemsModel.setProperty(netItemCard.index, "statusText", nextOn ? "Enabling..." : "Disabling...");
                                            wifiToggleProc.running = false;
                                            wifiToggleProc.running = true;
                                        } else if (netItemCard.model.itemType === "ethernet") {
                                            const nextEthOn = !netItemCard.model.active;
                                            root.netActionCmd = nextEthOn ? "eth_on" : "eth_off";
                                            root.netActionTarget = netItemCard.model.itemId;
                                            root.netActionPassword = "";
                                            netItemsModel.setProperty(netItemCard.index, "statusText", nextEthOn ? "Enabling..." : "Disabling...");
                                            netActionProc.running = false;
                                            netActionProc.running = true;
                                        } else {
                                            netListProc.running = false;
                                            netListProc.running = true;
                                        }
                                    }
                                }
                            }
                        }

                        // Consistent Full-Width Bottom Action Button
                        GlassBox {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            cornerRadius: 21
                            hovered: netOpenMouse.containsMouse
                            pressed: netOpenMouse.pressed

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "󰒓"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: Theme.text
                                }

                                Text {
                                    text: "Open Network Manager (nmtui)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: netOpenMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.controlCenterOpen = false;
                                    ShellState.launchTerminal("nmtui");
                                }
                            }
                        }
                    }

                    // ---------------- BLUETOOTH EXTENDED SUB-PAGE ----------------
                    ColumnLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 364
                        spacing: 10
                        opacity: ShellState.bluetoothExtended ? 1.0 : 0.0
                        visible: opacity > 0.01
                        enabled: ShellState.bluetoothExtended
                        transform: Translate {
                            id: btSubTrans
                            x: ShellState.bluetoothExtended ? 0 : 18
                            Behavior on x { NumberAnimation { duration: ShellState.animDur(360, 240); easing.type: ShellState.animPrimaryEase } }
                        }
                        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(280, 190); easing.type: ShellState.animPrimaryEase } }

                        // Consistent Submenu Header Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: 10

                            GlassBox {
                                implicitWidth: 34
                                implicitHeight: 34
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                cornerRadius: 17
                                hovered: btBackMouse.containsMouse
                                pressed: btBackMouse.pressed

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅁"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 16
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: btBackMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.bluetoothExtended = false
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Bluetooth Devices"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            GlassBox {
                                implicitWidth: 78
                                implicitHeight: 30
                                Layout.preferredWidth: 78
                                Layout.preferredHeight: 30
                                cornerRadius: 15
                                hovered: btScanTopMouse.containsMouse
                                pressed: btScanTopMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "󰑐"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                        color: Theme.text
                                    }
                                    Text {
                                        text: "Scan"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: btScanTopMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Quickshell.execDetached([ShellState.script("bluetooth-manager.sh"), "scan"]);
                                        btListProc.running = false;
                                        btListProc.running = true;
                                        btRefreshTimer.restart();
                                    }
                                }
                            }
                        }

                        // Scrollable Bluetooth Controller & Devices List (with smooth fade-out)
                        ListView {
                            id: btSubListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            topMargin: 4
                            bottomMargin: 14
                            model: btItemsModel
                            boundsBehavior: Flickable.StopAtBounds

                            property real scrollTargetY: 0
                            readonly property real topFade: Math.min(1.0, Math.max(0.0, contentY / 14.0))
                            readonly property real botFade: Math.min(1.0, Math.max(0.0, (contentHeight - height - contentY) / 14.0))

                            Behavior on contentY {
                                NumberAnimation { duration: 105; easing.type: Easing.OutCubic }
                            }

                            WheelHandler {
                                target: null
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    const maxContentY = Math.max(0, btSubListView.contentHeight - btSubListView.height);
                                    const delta = event.angleDelta.y;
                                    const step = (delta !== 0 ? (delta / 120.0) : (event.pixelDelta.y / 18.0)) * 110;
                                    btSubListView.scrollTargetY = Math.max(0, Math.min(maxContentY, btSubListView.scrollTargetY - step));
                                    btSubListView.contentY = btSubListView.scrollTargetY;
                                    event.accepted = true;
                                }
                            }

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Item {
                                    width: Math.max(1, btSubListView.width)
                                    height: Math.max(1, btSubListView.height)

                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0 - btSubListView.topFade) }
                                            GradientStop { position: 0.02; color: Qt.rgba(1, 1, 1, 1.0 - btSubListView.topFade) }
                                            GradientStop { position: 0.06; color: Qt.rgba(1, 1, 1, 1.0 - 0.65 * btSubListView.topFade) }
                                            GradientStop { position: 0.11; color: "#ffffffff" }
                                            GradientStop { position: 0.87; color: "#ffffffff" }
                                            GradientStop { position: 0.93; color: Qt.rgba(1, 1, 1, 1.0 - 0.68 * btSubListView.botFade) }
                                            GradientStop { position: 0.98; color: Qt.rgba(1, 1, 1, 1.0 - btSubListView.botFade) }
                                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.0 - btSubListView.botFade) }
                                        }
                                    }
                                }
                            }

                            delegate: GlassBox {
                                id: btItemCard
                                required property var model
                                required property int index
                                width: btSubListView.width
                                height: 64
                                cornerRadius: 16
                                active: model.active
                                hovered: btItemMouse.containsMouse
                                pressed: btItemMouse.pressed

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    GlassBadge {
                                        badgeSize: 38
                                        iconSize: 18
                                        active: btItemCard.model.active
                                        icon: btItemCard.model.icon
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: btItemCard.model.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: Theme.text
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: btItemCard.model.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.subtext
                                            elide: Text.ElideRight
                                        }
                                    }

                                    GlassBox {
                                        implicitWidth: 78
                                        implicitHeight: 28
                                        Layout.preferredWidth: 78
                                        Layout.preferredHeight: 28
                                        cornerRadius: 14
                                        active: btItemCard.model.active
                                        hovered: btItemMouse.containsMouse

                                        Text {
                                            anchors.centerIn: parent
                                            text: btItemCard.model.statusText
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: Theme.text
                                        }
                                    }
                                }

                                MouseArea {
                                    id: btItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (btItemCard.model.itemType === "adapter") {
                                            const nextOn = !root.btAdapterActive;
                                            root.btTargetCmd = nextOn ? "on" : "off";
                                            root.btAdapterActive = nextOn;
                                            root.btStatusText = nextOn ? "Turning on..." : "Off";
                                            btToggleProc.running = false;
                                            btToggleProc.running = true;
                                        } else {
                                            const act = btItemCard.model.active ? "disconnect" : "connect";
                                            Quickshell.execDetached([ShellState.script("bluetooth-manager.sh"), act, btItemCard.model.itemId]);
                                            btRefreshTimer.restart();
                                        }
                                    }
                                }
                            }
                        }

                        // Consistent Full-Width Bottom Action Button
                        GlassBox {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            cornerRadius: 21
                            hovered: btOpenCliMouse.containsMouse
                            pressed: btOpenCliMouse.pressed

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "󰂯"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: Theme.text
                                }

                                Text {
                                    text: "Open Bluetooth Console (bluetoothctl)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: btOpenCliMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.controlCenterOpen = false;
                                    ShellState.launchTerminal("bluetoothctl");
                                }
                            }
                        }
                    }

                    // ---------------- AUDIO OUTPUT EXTENDED SUB-PAGE ----------------
                    ColumnLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 364
                        spacing: 10
                        opacity: ShellState.audioExtended ? 1.0 : 0.0
                        visible: opacity > 0.01
                        enabled: ShellState.audioExtended
                        transform: Translate {
                            id: audioSubTrans
                            x: ShellState.audioExtended ? 0 : 18
                            Behavior on x { NumberAnimation { duration: ShellState.animDur(360, 240); easing.type: ShellState.animPrimaryEase } }
                        }
                        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(280, 190); easing.type: ShellState.animPrimaryEase } }

                        // Consistent Submenu Header Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: 10

                            GlassBox {
                                implicitWidth: 34
                                implicitHeight: 34
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                cornerRadius: 17
                                hovered: audioBackMouse.containsMouse
                                pressed: audioBackMouse.pressed

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰅁"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 16
                                    color: Theme.text
                                }

                                MouseArea {
                                    id: audioBackMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ShellState.audioExtended = false
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Audio Output"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            GlassBox {
                                implicitWidth: 78
                                implicitHeight: 30
                                Layout.preferredWidth: 78
                                Layout.preferredHeight: 30
                                cornerRadius: 15
                                hovered: audioRefreshMouse.containsMouse
                                pressed: audioRefreshMouse.pressed

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "󰑐"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 12
                                        color: Theme.text
                                    }
                                    Text {
                                        text: "Refresh"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.text
                                    }
                                }

                                MouseArea {
                                    id: audioRefreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audioListProc.running = true
                                }
                            }
                        }

                        // Scrollable Audio Output Sinks List (with balanced wheel scroll & smooth top/bottom fade-out)
                        ListView {
                            id: audioSubListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 8
                            topMargin: 4
                            bottomMargin: 14
                            model: audioSinksModel
                            boundsBehavior: Flickable.StopAtBounds

                            property real scrollTargetY: 0
                            readonly property real topFade: Math.min(1.0, Math.max(0.0, contentY / 14.0))
                            readonly property real botFade: Math.min(1.0, Math.max(0.0, (contentHeight - height - contentY) / 14.0))

                            Behavior on contentY {
                                NumberAnimation { duration: 105; easing.type: Easing.OutCubic }
                            }

                            WheelHandler {
                                target: null
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    const maxContentY = Math.max(0, audioSubListView.contentHeight - audioSubListView.height);
                                    const delta = event.angleDelta.y;
                                    const step = (delta !== 0 ? (delta / 120.0) : (event.pixelDelta.y / 18.0)) * 110;
                                    audioSubListView.scrollTargetY = Math.max(0, Math.min(maxContentY, audioSubListView.scrollTargetY - step));
                                    audioSubListView.contentY = audioSubListView.scrollTargetY;
                                    event.accepted = true;
                                }
                            }

                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Item {
                                    width: Math.max(1, audioSubListView.width)
                                    height: Math.max(1, audioSubListView.height)

                                    Rectangle {
                                        anchors.fill: parent
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0 - audioSubListView.topFade) }
                                            GradientStop { position: 0.02; color: Qt.rgba(1, 1, 1, 1.0 - audioSubListView.topFade) }
                                            GradientStop { position: 0.06; color: Qt.rgba(1, 1, 1, 1.0 - 0.65 * audioSubListView.topFade) }
                                            GradientStop { position: 0.11; color: "#ffffffff" }
                                            GradientStop { position: 0.87; color: "#ffffffff" }
                                            GradientStop { position: 0.93; color: Qt.rgba(1, 1, 1, 1.0 - 0.68 * audioSubListView.botFade) }
                                            GradientStop { position: 0.98; color: Qt.rgba(1, 1, 1, 1.0 - audioSubListView.botFade) }
                                            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.0 - audioSubListView.botFade) }
                                        }
                                    }
                                }
                            }

                            delegate: GlassBox {
                                id: sinkItemCard
                                required property var model
                                required property int index
                                width: audioSubListView.width
                                height: 64
                                cornerRadius: 16
                                active: model.active
                                hovered: sinkItemMouse.containsMouse
                                pressed: sinkItemMouse.pressed

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    GlassBadge {
                                        badgeSize: 38
                                        iconSize: 18
                                        active: sinkItemCard.model.active
                                        icon: sinkItemCard.model.icon
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: sinkItemCard.model.title
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: Theme.text
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: sinkItemCard.model.subtitle
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            color: Theme.subtext
                                            elide: Text.ElideRight
                                        }
                                    }

                                    GlassBox {
                                        implicitWidth: 78
                                        implicitHeight: 28
                                        Layout.preferredWidth: 78
                                        Layout.preferredHeight: 28
                                        cornerRadius: 14
                                        active: sinkItemCard.model.active
                                        hovered: sinkItemMouse.containsMouse

                                        Text {
                                            anchors.centerIn: parent
                                            text: sinkItemCard.model.active ? "Active" : "Select"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: Theme.text
                                        }
                                    }
                                }

                                MouseArea {
                                    id: sinkItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectAudioOutput(sinkItemCard.model.sinkName, sinkItemCard.model.sinkId);
                                    }
                                }
                            }
                        }

                        // Consistent Full-Width Bottom Action Button
                        GlassBox {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            cornerRadius: 21
                            hovered: audioMixerMouse.containsMouse
                            pressed: audioMixerMouse.pressed

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: "󰕾"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: Theme.text
                                }

                                Text {
                                    text: "Open Audio Mixer (alsamixer)"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }
                            }

                            MouseArea {
                                id: audioMixerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.controlCenterOpen = false;
                                    ShellState.launchTerminal("alsamixer");
                                }
                            }
                        }
                    }
                }

                // ================= TAB 1: MEDIA PLAYER VIEW =================
                MediaTab { id: mediaTabView; activeTab: panelContent.activeTab }
            }
        }

                        // ================= 3. PERSISTENT FLOATING ALBUM ART (TRUE SPATIAL MORPH) =================
                        // Smoothly glides & deforms with the bouncing capsule (no independent OutBack bounce!)
                        Item {
                            id: floatingAlbumArt
                            z: 10

                            readonly property real targetArtSize: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 158 : 50;
                                if (ShellState.mediaToastOpen) return 52;
                                return 24;
                            }
                            readonly property real targetArtRadius: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 26 : 14;
                                if (ShellState.mediaToastOpen) return 18;
                                return 8;
                            }
                            readonly property real targetArtX: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 26 : 299;
                                if (ShellState.mediaToastOpen) return 15;
                                return 14;
                            }
                            readonly property real targetArtY: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 77 : 70;
                                if (ShellState.mediaToastOpen) return 15;
                                return 7;
                            }
                            readonly property real targetArtOpacity: {
                                if (ShellState.isFloatingModalMode || ShellState.isModalMorphing || ShellState.lockVisualOpen) {
                                    return 0.0;
                                }
                                if (ShellState.centerIslandMode === "volume" || ShellState.centerIslandMode === "power" || ShellState.centerIslandMode === "notif" || ShellState.centerIslandMode === "kbLayout") {
                                    return 0.0;
                                }
                                if (ShellState.controlCenterOpen && panelContent.activeTab === 0 && (ShellState.networkExtended || ShellState.bluetoothExtended || ShellState.audioExtended)) {
                                    return 0.0;
                                }
                                if (!ShellState.controlCenterOpen && !ShellState.mediaToastOpen && !ShellState.showMediaOnIsland) {
                                    return 0.0;
                                }
                                return 1.0;
                            }

                            x: targetArtX
                            y: targetArtY
                            width: targetArtSize
                            height: targetArtSize
                            opacity: targetArtOpacity
                            visible: opacity > 0.005

                            property real artRadius: targetArtRadius

                            Behavior on x { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on y { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on width { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on height { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on artRadius { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: floatingAlbumArt.targetArtOpacity < floatingAlbumArt.opacity ? ShellState.animDur(220, 140) : ShellState.animDur(280, 210); easing.type: ShellState.animPrimaryEase } }

                            readonly property real combinedSpinAngle: (ShellState.albumArtSpinAngle + mediaTabView.sourceSwitchSpinAngle) % 360

                            transform: [
                                Scale {
                                    origin.x: floatingAlbumArt.width / 2
                                    origin.y: floatingAlbumArt.height / 2
                                    xScale: (floatingAlbumArt.combinedSpinAngle > 90 && floatingAlbumArt.combinedSpinAngle < 270) ? -1 : 1
                                },
                                Rotation {
                                    origin.x: floatingAlbumArt.width / 2
                                    origin.y: floatingAlbumArt.height / 2
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: floatingAlbumArt.combinedSpinAngle
                                }
                            ]

                            Image {
                                id: floatingArtImg
                                anchors.fill: parent
                                source: root.useAltTab1Player
                                    ? String(root.activeTab1Player.trackArtUrl || "")
                                    : (ShellState.displayedTrackArtUrl.length > 0 ? ShellState.displayedTrackArtUrl : root.mprisArtUrl)
                                sourceSize: Qt.size(256, 256)
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                asynchronous: false
                            }

                            Rectangle {
                                id: floatingArtMask
                                anchors.fill: parent
                                radius: floatingAlbumArt.artRadius
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: floatingArtImg
                                maskSource: floatingArtMask
                                visible: floatingArtImg.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: floatingAlbumArt.artRadius
                                color: Theme.glassCard
                                border.width: 1
                                border.color: Theme.glassBorder
                                visible: floatingArtImg.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎈"
                                    font.family: Theme.iconFont
                                    font.pixelSize: Math.max(12, Math.round(floatingAlbumArt.width * 0.34))
                                    color: ShellState.mediaArtColor
                                }
                            }

                            // Subtle glass rim border around the floating album art
                            Rectangle {
                                anchors.fill: parent
                                radius: floatingAlbumArt.artRadius
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.glassBorder
                                visible: floatingArtImg.status === Image.Ready
                            }
                        }

                        // ================= 3B. PERSISTENT FLOATING TRACK TITLE & ARTIST (TRUE SPATIAL MORPH) =================
                        // Smoothly glides & scales across Mini Bar Capsule <-> Medium Toast <-> Media Tab <-> Quick Settings Card
                        Item {
                            id: floatingTrackInfo
                            z: 10

                            readonly property string resolvedTitle: root.useAltTab1Player
                                ? (root.activeTab1Player.trackTitle && String(root.activeTab1Player.trackTitle).length > 0 ? String(root.activeTab1Player.trackTitle) : "Not Playing")
                                : (ShellState.displayedTrackTitle.length > 0
                                    ? ShellState.displayedTrackTitle
                                    : (root.mprisPlayer && root.mprisPlayer.trackTitle ? String(root.mprisPlayer.trackTitle) : "Not Playing"))

                            Text {
                                id: collapsedTitleProbe
                                visible: false
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.DemiBold
                                text: floatingTrackInfo.resolvedTitle
                            }

                            readonly property real collapsedSlotW: Math.max(20, ShellState.centerIslandBaseWidth - 94.5)
                            readonly property real collapsedCenteredX: 48 + Math.max(0, (collapsedSlotW - Math.min(collapsedTitleProbe.contentWidth, collapsedSlotW)) / 2)
                            readonly property real collapsedCenteredY: (Theme.barHeight - collapsedTitleProbe.contentHeight) / 2

                            readonly property real targetTextX: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 202 : 355;
                                if (ShellState.mediaToastOpen) return 80;
                                return collapsedCenteredX;
                            }
                            readonly property real targetTextY: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) {
                                    if (panelContent.activeTab === 1) {
                                        return root.mprisPlayerCount > 1 ? 105 : 83;
                                    }
                                    return 77;
                                }
                                if (ShellState.mediaToastOpen) return 30;
                                return collapsedCenteredY;
                            }
                            readonly property real targetTextWidth: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 276 : 165;
                                if (ShellState.mediaToastOpen) return 236;
                                return collapsedSlotW;
                            }
                            readonly property real targetTitleScale: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff) return panelContent.activeTab === 1 ? 1.12 : 0.92;
                                return 1.0;
                            }
                            readonly property real targetArtistOpacity: {
                                if (ShellState.controlCenterOpen || root.isModalHandoff || ShellState.mediaToastOpen) return 1.0;
                                return 0.0;
                            }
                            readonly property real targetInfoOpacity: {
                                if (ShellState.isFloatingModalMode || ShellState.isModalMorphing || ShellState.lockVisualOpen) {
                                    return 0.0;
                                }
                                if (ShellState.centerIslandMode === "volume" || ShellState.centerIslandMode === "power" || ShellState.centerIslandMode === "notif" || ShellState.centerIslandMode === "kbLayout") {
                                    return 0.0;
                                }
                                if (ShellState.controlCenterOpen && panelContent.activeTab === 0 && (ShellState.networkExtended || ShellState.bluetoothExtended || ShellState.audioExtended)) {
                                    return 0.0;
                                }
                                if (!ShellState.controlCenterOpen && !ShellState.mediaToastOpen && !ShellState.showMediaOnIsland) {
                                    return 0.0;
                                }
                                return 1.0;
                            }

                            x: targetTextX
                            y: targetTextY
                            width: targetTextWidth
                            height: 40
                            property real titleScale: targetTitleScale
                            property real artistOpacity: targetArtistOpacity
                            property real infoOpacity: targetInfoOpacity
                            opacity: infoOpacity * ShellState.trackSwitchTextOpacity * mediaTabView.sourceSwitchOpacity
                            visible: opacity > 0.005

                            Behavior on x { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on y { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on width { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on titleScale { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on artistOpacity { enabled: root.visible; NumberAnimation { duration: floatingTrackInfo.targetArtistOpacity < floatingTrackInfo.artistOpacity ? ShellState.animDur(220, 140) : ShellState.animDur(280, 210); easing.type: ShellState.animPrimaryEase } }
                            Behavior on infoOpacity { enabled: root.visible; NumberAnimation { duration: floatingTrackInfo.targetInfoOpacity < floatingTrackInfo.infoOpacity ? ShellState.animDur(220, 130) : ShellState.animDur(280, 210); easing.type: ShellState.animPrimaryEase } }

                            transform: [
                                Translate {
                                    y: ShellState.trackSwitchTextOffsetY + mediaTabView.sourceSwitchOffsetY
                                },
                                Scale {
                                    origin.x: 0
                                    origin.y: 0
                                    xScale: floatingTrackInfo.titleScale
                                    yScale: floatingTrackInfo.titleScale
                                }
                            ]

                            Column {
                                width: parent.width
                                spacing: 2

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    text: floatingTrackInfo.resolvedTitle
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.weight: (ShellState.controlCenterOpen && panelContent.activeTab === 1) || ShellState.mediaToastOpen ? Font.Bold : Font.DemiBold
                                    color: Theme.text
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignLeft
                                    elide: Text.ElideRight
                                    opacity: floatingTrackInfo.artistOpacity
                                    visible: opacity > 0.005
                                    text: root.useAltTab1Player
                                        ? (root.activeTab1Player.trackArtist && String(root.activeTab1Player.trackArtist).length > 0
                                            ? String(root.activeTab1Player.trackArtist)
                                            : (root.activeTab1Player.identity ? String(root.activeTab1Player.identity) : "Unknown Artist"))
                                        : (ShellState.displayedTrackArtist.length > 0
                                            ? ShellState.displayedTrackArtist
                                            : (root.mprisPlayer && root.mprisPlayer.trackArtist ? String(root.mprisPlayer.trackArtist) : "Tap to open player"))
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: Theme.subtext
                                }
                            }
                        }

                        // ================= 4. PERSISTENT FLOATING WAVEFORM =================
                        // Smoothly follows the panel stretch & deforms with it; bars sit in fixed-height slots so they never jump vertically
                        Item {
                            id: floatingWaveform
                            z: 10
                            width: 22.5
                            height: 18

                            property real rightPad: {
                                if ((ShellState.controlCenterOpen || root.isModalHandoff) && panelContent.activeTab === 1) return 26;
                                if (ShellState.mediaToastOpen) return 18;
                                return 14;
                            }
                            readonly property real targetWaveY: {
                                if ((ShellState.controlCenterOpen || root.isModalHandoff) && panelContent.activeTab === 1) return root.mprisPlayerCount > 1 ? 79 : 92;
                                if (ShellState.mediaToastOpen) return 32;
                                return 10;
                            }
                            readonly property real targetWaveOpacity: {
                                if (ShellState.isFloatingModalMode || ShellState.isModalMorphing || ShellState.lockVisualOpen) return 0.0;
                                if (ShellState.centerIslandMode === "volume" || ShellState.centerIslandMode === "power" || ShellState.centerIslandMode === "notif" || ShellState.centerIslandMode === "kbLayout") return 0.0;
                                if (ShellState.controlCenterOpen && panelContent.activeTab === 0) return 0.0;
                                if (!ShellState.controlCenterOpen && !ShellState.mediaToastOpen && !ShellState.showMediaOnIsland) return 0.0;
                                return 1.0;
                            }

                            x: islandDeformLayer.width - rightPad - width
                            y: targetWaveY
                            opacity: targetWaveOpacity
                            visible: opacity > 0.005

                            Behavior on rightPad { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on y { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
                            Behavior on opacity { enabled: root.visible; NumberAnimation { duration: ShellState.animDur(280, 210); easing.type: ShellState.animPrimaryEase } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 2.5
                                height: 18

                                Repeater {
                                    model: 5
                                    delegate: Item {
                                        required property int index
                                        width: 2.5
                                        height: 18

                                        Rectangle {
                                            width: 2.5
                                            radius: 1.25
                                            x: 0
                                            y: (parent.height - height) / 2
                                            color: root.isMprisPlaying ? ShellState.mediaArtColor : Theme.textDim
                                            readonly property real waveVal: ShellState.waveBand(index)
                                            height: 3.5 + 13.5 * waveVal

                                            Behavior on color {
                                                ColorAnimation { duration: 300; easing.type: Easing.InOutCubic }
                                            }
                                        }
                                    }
                                }
                            }
                        }
        }
    }
}
