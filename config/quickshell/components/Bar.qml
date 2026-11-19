import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import ".."

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 0
        left: 0
        right: 0
    }

    implicitHeight: Theme.barBottomY
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    exclusiveZone: implicitHeight

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property bool isMainMonitor: ShellState.isMainScreen(root.screen)
    readonly property string screenName: root.screen ? String(root.screen.name || "") : Theme.mainMonitorName
    readonly property bool ownsActivePanel: root.screenName === ShellState.activeMonitorName
    readonly property real screenW: root.screen ? root.screen.width : ShellState.mainScreenWidth
    readonly property real screenH: root.screen ? root.screen.height : ShellState.mainScreenHeight

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool isMuted: audio ? audio.muted : false
    readonly property real vol: (audio && !isNaN(audio.volume)) ? Math.min(1.0, Math.max(0.0, audio.volume)) : 0.0

    function getPlayingPlayer() {
        return ShellState.islandMediaPlayer;
    }

    readonly property var activePlayer: getPlayingPlayer()
    readonly property bool hasIslandMedia: ShellState.showMediaOnIsland
    readonly property bool isMediaPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property string playingTitle: (activePlayer && activePlayer.trackTitle) ? String(activePlayer.trackTitle) : ""
    readonly property string playingArtist: (activePlayer && activePlayer.trackArtist) ? String(activePlayer.trackArtist) : ""
    readonly property string playingArtUrl: (activePlayer && activePlayer.trackArtUrl) ? String(activePlayer.trackArtUrl) : ""

    property string lastAnnouncedTitle: ""
    property bool mediaTrackerReady: false

    Timer {
        interval: 800
        running: root.isMainMonitor
        repeat: false
        onTriggered: {
            root.lastAnnouncedTitle = root.playingTitle;
            ShellState.updateTrackMetadata(root.playingTitle, root.playingArtist, root.playingArtUrl, false);
            root.mediaTrackerReady = true;
            if (root.playingArtUrl.length > 0) {
                ShellState.extractAlbumArtColor(root.playingArtUrl);
            }
        }
    }

    Timer {
        id: trackUpdateDebounce
        interval: 40
        repeat: false
        onTriggered: {
            if (!root.isMainMonitor) return;
            if (root.playingTitle.length > 0) {
                clearTrackTimer.stop();
                ShellState.updateTrackMetadata(root.playingTitle, root.playingArtist, root.playingArtUrl, root.mediaTrackerReady);
            } else {
                clearTrackTimer.restart();
            }
        }
    }

    Timer {
        id: clearTrackTimer
        interval: 460
        repeat: false
        onTriggered: {
            if (root.isMainMonitor && !root.hasIslandMedia && root.playingTitle.length === 0) {
                ShellState.updateTrackMetadata("", "", "", root.mediaTrackerReady);
            }
        }
    }

    onPlayingArtUrlChanged: {
        if (!root.isMainMonitor) return;
        if (root.mediaTrackerReady) trackUpdateDebounce.restart();
        else ShellState.extractAlbumArtColor(root.playingArtUrl);
    }

    onPlayingArtistChanged: {
        if (root.isMainMonitor && root.mediaTrackerReady) trackUpdateDebounce.restart();
    }

    onPlayingTitleChanged: {
        if (!root.isMainMonitor || !root.mediaTrackerReady) return;
        trackUpdateDebounce.restart();
        if (root.isMediaPlaying && root.playingTitle.length > 0 && root.playingTitle !== root.lastAnnouncedTitle) {
            root.lastAnnouncedTitle = root.playingTitle;
            ShellState.triggerMediaToast();
        } else if (!root.isMediaPlaying) {
            root.lastAnnouncedTitle = "";
        }
    }

    onIsMediaPlayingChanged: {
        if (!root.isMainMonitor || !root.mediaTrackerReady) return;
        if (root.isMediaPlaying && root.playingTitle.length > 0 && root.playingTitle !== root.lastAnnouncedTitle) {
            root.lastAnnouncedTitle = root.playingTitle;
            trackUpdateDebounce.restart();
            ShellState.triggerMediaToast();
        }
    }

    readonly property bool isMediaOverlayVisible: root.ownsActivePanel && ShellState.ccOverlayVisible

    TextMetrics {
        id: mediaTitleMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeNormal
        font.weight: Font.DemiBold
        text: ShellState.displayedTrackTitle.length > 0 ? ShellState.displayedTrackTitle : (root.playingTitle.length > 0 ? root.playingTitle : "Playing")
    }

    // Sync the 3 island resting widths to ShellState so ScreenFrame's 3 morphing islands match the live bar contents
    readonly property real activeCenterContentW: root.hasIslandMedia
        ? (24 + 10 + Math.min(210, Math.ceil(mediaTitleMetrics.advanceWidth)) + 10 + 23)
        : idleWindowItem.implicitWidth
    readonly property real calcLeftW: Math.max(
        152,
        launcherBtn.implicitWidth + 10 + workspacesWidget.targetWidth
            + (ShellState.showDebugButton ? (10 + weatherDebugBtn.Layout.preferredWidth) : 0)
            + (scratchpadsWidget.count > 0 ? (10 + scratchpadsWidget.targetWidth) : 0) + 28
    )
    readonly property real calcCenterW: root.hasIslandMedia ? Math.max(96, activeCenterContentW + 28) : Math.max(76, activeCenterContentW + 22)
    property real smoothCenterW: calcCenterW
    Behavior on smoothCenterW { NumberAnimation { duration: ShellState.animDur(340, 240); easing.type: ShellState.animPrimaryEase } }
    readonly property real calcRightW: Math.max(248, rightRow.implicitWidth + 28)

    function syncMonitorWidths() {
        ShellState.setSecondaryBarWidths(root.screenName, calcLeftW, calcCenterW, calcRightW, leftRow.launcherSlotX);
    }

    onCalcLeftWChanged: syncMonitorWidths()
    onCalcCenterWChanged: syncMonitorWidths()
    onCalcRightWChanged: syncMonitorWidths()

    Component.onCompleted: syncMonitorWidths()

    DesktopCaptureSource {
        id: barCap
        targetScreen: root.screen
        sceneWidth: root.screenW
        sceneHeight: root.screenH
        active: ShellState.liquidGlassEnabled && (barContent.anyLeftBarPillHighlighted || (rightIslandHeaderBox.visible && rightIslandHeaderBox.anyRightPillHighlighted))
    }

    // Offscreen synced weather sky feeding WeatherWidget's crossfade glass layer while Weather is open or fading out
    Item {
        width: 0
        height: 0
        clip: true
        visible: ShellState.liquidGlassEnabled && rightIslandHeaderBox.weatherSkyActive

        WeatherSkyBackdrop {
            id: barWeatherSkyScene
            x: 0
            y: 0
            width: Math.max(1, ShellState.rightIslandWidth)
            height: Math.max(1, ShellState.rightIslandHeight)
        }
    }

    ShaderEffectSource {
        id: rightWeatherSkySource
        visible: false
        sourceItem: barWeatherSkyScene
        hideSource: true
        live: ShellState.liquidGlassEnabled && rightIslandHeaderBox.weatherSkyActive && (rightIslandHeaderBox.anyRightPillHighlighted || ShellState.weatherSkyProgress > 0.005)
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(barWeatherSkyScene.width)), Math.max(1, Math.round(barWeatherSkyScene.height)))
    }

    // Transparent widget container — the 3 morphing island capsules are painted seamlessly by ScreenFrame.qml
    Item {
        anchors.fill: parent

        // 3-Island Bar Content Area
        Item {
            id: barContent
            readonly property bool liquidGlassHost: true
            readonly property var liquidSource: barCap.textureSource
            readonly property bool liquidSourceReady: barCap.ready
            readonly property real liquidOriginX: 0
            readonly property real liquidOriginY: 0
            readonly property real liquidTexWidth: root.screenW
            readonly property real liquidTexHeight: root.screenH
            readonly property real liquidLayoutRev: (root.ownsActivePanel
                ? (ShellState.leftIslandWidth + ShellState.rightIslandWidth + ShellState.centerIslandWidth)
                : (root.calcLeftW + root.calcCenterW + root.calcRightW))
                + (ShellState.showDebugButton ? 1000.0 : 0.0)
                + (ShellState.secondaryFullBar ? 2000.0 : 0.0)
            readonly property bool anyLeftBarPillHighlighted: launcherBtn.isPillHighlighted
                || workspacesWidget.isPillHighlighted
                || weatherDebugBtn.isPillHighlighted
                || scratchpadsWidget.isPillHighlighted

            x: Theme.barMarginX
            y: Theme.barTopGap
            width: parent.width - Theme.barMarginX * 2
            height: Theme.barHeight

            // 1. LEFT ISLAND HEADER: Arch trigger, Workspaces switcher, Test Notification, Active Scratchpads
            Item {
                id: leftIslandHeaderBox
                anchors.left: parent.left
                anchors.top: parent.top
                width: root.ownsActivePanel ? ShellState.leftIslandWidth : root.calcLeftW
                height: Theme.barHeight

                RowLayout {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    readonly property real launcherSlotX: x + launcherBtn.x
                    onLauncherSlotXChanged: {
                        ShellState.setSecondaryBarWidths(root.screenName, root.calcLeftW, root.calcCenterW, root.calcRightW, launcherSlotX);
                        if (root.ownsActivePanel && !ShellState.sysMenuOpen && ShellState.leftIslandHeight <= Theme.barHeight + 0.5) {
                            ShellState.archLogoBarX = launcherSlotX;
                        }
                    }
                    Component.onCompleted: {
                        if (root.ownsActivePanel) ShellState.archLogoBarX = launcherSlotX;
                    }

                    LauncherButton { id: launcherBtn; targetScreen: root.screen; ownsActivePanel: root.ownsActivePanel }
                    Workspaces { id: workspacesWidget; targetScreen: root.screen; ownsActivePanel: root.ownsActivePanel }

                    // Mini Debug Menu Trigger (Test Notification + Weather State Preview)
                    Rectangle {
                        id: weatherDebugBtn
                        visible: ShellState.showDebugButton
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        radius: height / 2
                        readonly property bool isDebugActive: ShellState.weatherDebugOpen || ShellState.weatherDebugMode.length > 0
                        readonly property bool isPillHighlighted: ShellState.showDebugButton && (isDebugActive || weatherDebugMouse.containsMouse)
                        color: dbgBtnLg.isLiquidActive
                            ? "transparent"
                            : (weatherDebugMouse.pressed
                                ? Theme.glassSurfaceActive
                                : (isDebugActive
                                    ? Theme.glassSurfaceActive
                                    : (weatherDebugMouse.containsMouse ? Theme.glassSurfaceHover : "transparent")))
                        scale: weatherDebugMouse.pressed ? 0.90 : (weatherDebugMouse.containsMouse ? 1.05 : 1.0)

                        LiquidGlassSurface {
                            id: dbgBtnLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: parent.height / 2
                            active: weatherDebugBtn.isDebugActive
                            hovered: weatherDebugMouse.containsMouse
                            onlyWhenHighlighted: true
                        }

                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: ShellState.weatherDebugMode.length > 0 ? ShellState.weatherIcon : "󰃤"
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                            color: (weatherDebugBtn.isDebugActive || weatherDebugMouse.containsMouse) ? Theme.accent : Theme.subtext
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }

                        MouseArea {
                            id: weatherDebugMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ShellState.activateMonitor(root.screen);
                                const pos = weatherDebugBtn.mapToItem(null, 0, 0);
                                ShellState.weatherDebugCenterX = pos.x + weatherDebugBtn.width / 2;
                                ShellState.toggleWeatherDebugMenu();
                            }
                        }
                    }

                    ScratchpadsWidget { id: scratchpadsWidget }
                }
            }

            // 2. CENTER DYNAMIC ISLAND (Collapsed Capsule View: Either Window Name OR Album Art + Track + Waveform)
            Item {
                id: dynamicIslandBox
                visible: root.isMainMonitor || ShellState.secondaryFullBar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: root.ownsActivePanel ? ShellState.centerIslandWidth : root.smoothCenterW
                height: root.ownsActivePanel ? ShellState.centerIslandHeight : Theme.barHeight
                clip: true

                // Smooth simultaneous crossfade whenever the Dynamic Island changes content;
                // hold collapsed content hidden while the capsule is floating away in the middle of the screen.
                property real capsuleOpacity: root.ownsActivePanel
                    ? ((ShellState.centerIslandMode === "collapsed"
                        && ShellState.centerIslandY <= Theme.barTopGap + 32
                        && ShellState.centerIslandHeight <= Theme.barHeight + 18) ? 1.0 : 0.0)
                    : 1.0
                Behavior on capsuleOpacity {
                    NumberAnimation { duration: ShellState.animDur(230, 140); easing.type: ShellState.animPrimaryEase }
                }

                Item {
                    id: capsuleDeformBox
                    property real restingBaseW: root.calcCenterW
                    Behavior on restingBaseW { NumberAnimation { duration: ShellState.animDur(340, 240); easing.type: ShellState.animPrimaryEase } }
                    width: root.ownsActivePanel ? capsuleDeformBox.restingBaseW : root.smoothCenterW
                    height: Theme.barHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    visible: dynamicIslandBox.capsuleOpacity > 0.005 || capsuleDeformBox.mediaOverlayFade > 0.005

                    property real mediaActiveFade: root.hasIslandMedia ? 1.0 : 0.0
                    Behavior on mediaActiveFade { NumberAnimation { duration: ShellState.animDur(340, 240); easing.type: Easing.InOutCubic } }

                    // Brief overlap only on Bar -> ControlCenter handoff; snaps back to 1.0 instantly on return
                    property real mediaOverlayFade: 1.0

                    Component.onCompleted: mediaOverlayFade = root.isMediaOverlayVisible ? 0.0 : 1.0

                    NumberAnimation {
                        id: mediaOverlayFadeOutAnim
                        target: capsuleDeformBox
                        property: "mediaOverlayFade"
                        to: 0.0
                        duration: 36
                        easing.type: Easing.Linear
                    }

                    Connections {
                        target: root
                        function onIsMediaOverlayVisibleChanged() {
                            if (root.isMediaOverlayVisible) {
                                mediaOverlayFadeOutAnim.restart();
                            } else {
                                mediaOverlayFadeOutAnim.stop();
                                capsuleDeformBox.mediaOverlayFade = 1.0;
                            }
                        }
                    }

                    transform: Scale {
                        origin.x: capsuleDeformBox.width / 2
                        origin.y: capsuleDeformBox.height / 2
                        xScale: root.ownsActivePanel ? Math.max(0.82, Math.min(1.12, ShellState.centerIslandWidth / Math.max(1, capsuleDeformBox.width))) : 1.0
                        yScale: root.ownsActivePanel ? ShellState.islandDeformScaleY : 1.0
                    }

                    // STATE A: Idle (No media playing) -> Inside capsuleDeformBox so it squeezes and bounces with the island
                    ActiveWindow {
                        id: idleWindowItem
                        targetScreen: root.screen
                        ownsActivePanel: root.ownsActivePanel
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (Theme.barHeight - height) / 2
                        opacity: (ShellState.showWindowTitle ? 1.0 : 0.0) * dynamicIslandBox.capsuleOpacity * (1.0 - capsuleDeformBox.mediaActiveFade)
                        transformOrigin: Item.Center
                        scale: 0.94 + 0.06 * (1.0 - capsuleDeformBox.mediaActiveFade)
                        visible: opacity > 0.005
                    }

                    // STATE B: Media Playing -> Display ONLY Album Art + Track Name + Album-Colored Waveform
                    // Anchored to left/right edges so elements physically squeeze together and bounce apart with the capsule!
                    RowLayout {
                        id: mediaCapsuleRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: capsuleDeformBox.mediaActiveFade
                        transformOrigin: Item.Center
                        scale: 0.94 + 0.06 * capsuleDeformBox.mediaActiveFade
                        visible: opacity > 0.005
                        spacing: 10

                        // Rounded Mini Album Art (24x24) — seamlessly handed off to ControlCenter's floatingAlbumArt during morph
                        Item {
                            id: miniArtBox
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Layout.alignment: Qt.AlignVCenter
                            opacity: capsuleDeformBox.mediaOverlayFade * dynamicIslandBox.capsuleOpacity

                            transform: [
                                Scale {
                                    origin.x: miniArtBox.width / 2
                                    origin.y: miniArtBox.height / 2
                                    xScale: (ShellState.albumArtSpinAngle > 90 && ShellState.albumArtSpinAngle < 270) ? -1 : 1
                                },
                                Rotation {
                                    origin.x: miniArtBox.width / 2
                                    origin.y: miniArtBox.height / 2
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: ShellState.albumArtSpinAngle
                                }
                            ]

                            Image {
                                id: miniArtImg
                                anchors.fill: parent
                                source: ShellState.displayedTrackArtUrl.length > 0 ? ShellState.displayedTrackArtUrl : root.playingArtUrl
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                asynchronous: true
                            }

                            Rectangle {
                                id: miniArtMask
                                anchors.fill: parent
                                radius: 8
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: miniArtImg
                                maskSource: miniArtMask
                                visible: miniArtImg.status === Image.Ready
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: Theme.glassCard
                                border.width: 1
                                border.color: Theme.glassBorder
                                visible: miniArtImg.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰎈"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 12
                                    color: ShellState.mediaArtColor
                                }
                            }
                        }

                        // Track Title — seamlessly handed off to ControlCenter's floatingTrackInfo during expansion
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: ShellState.displayedTrackTitle.length > 0 ? ShellState.displayedTrackTitle : (root.playingTitle.length > 0 ? root.playingTitle : "Playing")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            font.weight: Font.DemiBold
                            color: Theme.text
                            opacity: capsuleDeformBox.mediaOverlayFade * dynamicIslandBox.capsuleOpacity * ShellState.trackSwitchTextOpacity
                            transform: Translate {
                                y: ShellState.trackSwitchTextOffsetY
                            }
                            layer.enabled: ShellState.liquidGlassEnabled
                            layer.effect: DropShadow {
                                verticalOffset: 1
                                radius: 4
                                samples: 9
                                color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
                            }
                        }

                        // Album-Art-Colored Waveform (5 animated bars in fixed-height slots so it never jumps vertically)
                        Row {
                            id: miniWaveformRow
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2.5
                            height: 18
                            opacity: capsuleDeformBox.mediaOverlayFade * dynamicIslandBox.capsuleOpacity

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
                                        color: root.isMediaPlaying ? ShellState.mediaArtColor : Theme.textDim
                                        Behavior on color { ColorAnimation { duration: 240 } }
                                        readonly property real waveVal: ShellState.waveBand(index)
                                        height: 3.5 + 13.5 * waveVal
                                    }
                                }
                            }
                        }
                    }
                }

                // Dynamic Island Interactive Trigger:
                // - When media is playing and user hovers -> expands into the Medium "Now Playing" Capsule
                // - Only a click expands into the Full Panel (Media tab if playing, Quick tab if idle)
                MouseArea {
                    id: islandMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.ownsActivePanel || ShellState.centerIslandMode === "collapsed" || ShellState.centerIslandMode === "mediaToast"
                    onEntered: {
                        if (root.hasIslandMedia && !ShellState.controlCenterOpen) {
                            ShellState.activateMonitor(root.screen);
                            ShellState.showMediaToastOnHover();
                        }
                    }
                    onClicked: {
                        ShellState.activateMonitor(root.screen);
                        ShellState.mediaToastOpen = false;
                        ShellState.ccActiveTab = root.hasIslandMedia ? 1 : 0;
                        ShellState.toggleControlCenter();
                    }
                    onWheel: wheel => {
                        if (root.audio) {
                            ShellState.activateMonitor(root.screen);
                            const delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                            root.audio.volume = Math.max(0.0, Math.min(1.0, root.vol + delta));
                            ShellState.triggerVolumeOsd();
                        }
                    }
                }
            }

            // 3. RIGHT ISLAND HEADER: System Tray, Weather, Battery, Clock, Notifications
            Item {
                id: rightIslandHeaderBox
                visible: root.isMainMonitor || ShellState.secondaryFullBar
                readonly property bool liquidGlassHost: true
                readonly property bool weatherSkyActive: root.ownsActivePanel && (ShellState.weatherOpen || ShellState.weatherSkyProgress > 0.005)
                readonly property bool anyRightPillHighlighted: systemTrayWidget.isPillHighlighted
                    || weatherWidget.isPillHighlighted
                    || clockWidget.isPillHighlighted
                    || notifBtn.isPillHighlighted
                readonly property var liquidSource: barCap.textureSource
                readonly property bool liquidSourceReady: barCap.ready
                readonly property real liquidOriginX: 0
                readonly property real liquidOriginY: 0
                readonly property real liquidTexWidth: root.screenW
                readonly property real liquidTexHeight: root.screenH
                readonly property real liquidLayoutRev: (root.ownsActivePanel
                    ? (ShellState.rightIslandWidth + ShellState.rightIslandHeight * 3.0)
                    : root.calcRightW)
                    + (weatherSkyActive ? 1000.0 : 0.0)
                    + (ShellState.secondaryFullBar ? 2000.0 : 0.0)

                anchors.right: parent.right
                anchors.top: parent.top
                width: root.ownsActivePanel ? ShellState.rightIslandWidth : root.calcRightW
                height: Theme.barHeight

                RowLayout {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    SystemTrayWidget { id: systemTrayWidget; targetScreen: root.screen }
                    WeatherWidget {
                        id: weatherWidget
                        targetScreen: root.screen
                        ownsActivePanel: root.ownsActivePanel
                        skySource: rightWeatherSkySource
                        skyOriginX: -(barContent.x + rightIslandHeaderBox.x)
                        skyOriginY: -Theme.barTopGap
                    }
                    BatteryWidget {}
                    ClockWidget { id: clockWidget; targetScreen: root.screen; ownsActivePanel: root.ownsActivePanel }
                    NotificationButton { id: notifBtn; targetScreen: root.screen; ownsActivePanel: root.ownsActivePanel }
                }
            }
        }
    }
}
