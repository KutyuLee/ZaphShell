import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../.."
import ".."

Item {
    id: mediaTab
    required property int activeTab
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 192
    opacity: mediaTab.activeTab === 1 ? 1.0 : 0.0
    visible: opacity > 0.01
    enabled: mediaTab.activeTab === 1
    transform: Translate {
        id: mediaTabTrans
        x: mediaTab.activeTab === 1 ? 0 : (mediaTab.activeTab > 1 ? -16 : 16)
        Behavior on x { NumberAnimation { duration: ShellState.animDur(360, 265); easing.type: ShellState.animPrimaryEase } }
    }
    readonly property real slideX: mediaTabTrans.x
    Behavior on opacity { NumberAnimation { duration: ShellState.animDur(300, 220); easing.type: ShellState.animPrimaryEase } }

    property int playerIndex: 0
    property int pendingPlayerDelta: 0
    property real sourceSwitchSpinAngle: 0.0
    property real sourceSwitchOpacity: 1.0
    property real sourceSwitchOffsetY: 0.0
    readonly property var playerList: ShellState.orderedMediaPlayers()
    readonly property int playerCount: playerList.length
    readonly property var player: playerCount > 0 ? playerList[Math.max(0, Math.min(playerIndex, playerCount - 1))] : null
    readonly property bool isPlaying: player ? player.playbackState === MprisPlaybackState.Playing : false
    readonly property string playerCtlName: (player && player.dbusName) ? String(player.dbusName).replace(/^org\.mpris\.MediaPlayer2\./, "") : ""

    SequentialAnimation {
        id: sourceSwitchAnim

        ParallelAnimation {
            NumberAnimation {
                target: mediaTab
                property: "sourceSwitchSpinAngle"
                from: 0
                to: 90
                duration: 135
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: mediaTab
                property: "sourceSwitchOpacity"
                to: 0.0
                duration: 125
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: mediaTab
                property: "sourceSwitchOffsetY"
                to: mediaTab.pendingPlayerDelta >= 0 ? -5.0 : 5.0
                duration: 125
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                if (mediaTab.playerCount > 0) {
                    mediaTab.playerIndex = (mediaTab.playerIndex + mediaTab.pendingPlayerDelta + mediaTab.playerCount) % mediaTab.playerCount;
                }
                mediaTab.sourceSwitchOffsetY = mediaTab.pendingPlayerDelta >= 0 ? 5.0 : -5.0;
            }
        }
        ParallelAnimation {
            NumberAnimation {
                target: mediaTab
                property: "sourceSwitchSpinAngle"
                from: 90
                to: 180
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: mediaTab
                property: "sourceSwitchOpacity"
                to: 1.0
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: mediaTab
                property: "sourceSwitchOffsetY"
                to: 0.0
                duration: 210
                easing.type: Easing.OutCubic
            }
        }
        PropertyAction {
            target: mediaTab
            property: "sourceSwitchSpinAngle"
            value: 0.0
        }
    }

    function switchPlayerSource(delta) {
        if (playerCount <= 1) return;
        if (sourceSwitchAnim.running) {
            sourceSwitchAnim.complete();
        }
        pendingPlayerDelta = delta;
        sourceSwitchAnim.restart();
    }

    onPlayerCountChanged: {
        if (playerCount <= 0) {
            playerIndex = 0;
        } else if (playerIndex >= playerCount) {
            playerIndex = playerCount - 1;
        }
    }

    Connections {
        target: ShellState
        function onControlCenterOpenChanged() {
            if (!ShellState.controlCenterOpen) {
                sourceSwitchAnim.stop();
                mediaTab.sourceSwitchSpinAngle = 0.0;
                mediaTab.sourceSwitchOpacity = 1.0;
                mediaTab.sourceSwitchOffsetY = 0.0;
                mediaTab.playerIndex = 0;
            }
        }
    }

    function formatTime(sec) {
        if (isNaN(sec) || sec <= 0) return "0:00";
        let s = Math.floor(sec > 100000 ? sec / 1000000 : sec);
        let m = Math.floor(s / 60);
        let remS = s % 60;
        return m + ":" + (remS < 10 ? "0" : "") + remS;
    }

    readonly property real trackLength: (player && player.length > 0) ? (player.length > 100000 ? player.length / 1000000 : player.length) : 0
    property real realtimePosition: 0
    property real basePosSec: 0
    property real lastSyncMs: 0
    readonly property real progress: trackLength > 0 ? Math.min(1.0, Math.max(0.0, realtimePosition / trackLength)) : 0.0

    function syncFromPlayerObj() {
        if (mediaTab.player) {
            const p = mediaTab.player.position || 0;
            const sec = p > 100000 ? p / 1000000 : p;
            mediaTab.basePosSec = sec;
            mediaTab.lastSyncMs = Date.now();
            if (!scrubberMouse.pressed) {
                mediaTab.realtimePosition = sec;
            }
        } else {
            mediaTab.basePosSec = 0;
            mediaTab.lastSyncMs = 0;
            mediaTab.realtimePosition = 0;
        }
    }

    onPlayerChanged: syncFromPlayerObj()

    Timer {
        id: posTicker
        interval: 50
        repeat: true
        running: mediaTab.isPlaying && mediaTab.activeTab === 1 && ShellState.controlCenterOpen && !scrubberMouse.pressed
        onTriggered: {
            if (mediaTab.isPlaying && mediaTab.lastSyncMs > 0) {
                const elapsed = (Date.now() - mediaTab.lastSyncMs) / 1000.0;
                mediaTab.realtimePosition = Math.min(mediaTab.trackLength, mediaTab.basePosSec + elapsed);
            }
        }
    }

    Process {
        id: posSyncProc
        command: mediaTab.playerCtlName.length > 0 ? ["playerctl", "-p", mediaTab.playerCtlName, "position"] : ["playerctl", "position"]
        stdout: SplitParser {
            onRead: data => {
                const val = parseFloat(data.trim());
                if (!isNaN(val) && val >= 0) {
                    mediaTab.basePosSec = val;
                    mediaTab.lastSyncMs = Date.now();
                    if (!scrubberMouse.pressed) {
                        mediaTab.realtimePosition = val;
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: mediaTab.isPlaying && mediaTab.activeTab === 1 && ShellState.controlCenterOpen && !scrubberMouse.pressed
        onTriggered: {
            if (mediaTab.playerCtlName.length > 0) {
                if (!posSyncProc.running) posSyncProc.running = true;
            } else {
                mediaTab.syncFromPlayerObj();
            }
        }
    }

    Connections {
        target: mediaTab.player
        function onPlaybackStateChanged() {
            if (mediaTab.playerCtlName.length > 0 && !posSyncProc.running) posSyncProc.running = true;
            else mediaTab.syncFromPlayerObj();
        }
        function onTrackTitleChanged() {
            if (mediaTab.playerCtlName.length > 0 && !posSyncProc.running) posSyncProc.running = true;
            else mediaTab.syncFromPlayerObj();
        }
        function onPositionChanged() {
            if (!scrubberMouse.pressed) {
                mediaTab.syncFromPlayerObj();
            }
        }
    }

    onActiveTabChanged: {
        if (mediaTab.activeTab === 1) {
            mediaTab.syncFromPlayerObj();
            if (mediaTab.playerCtlName.length > 0 && !posSyncProc.running) {
                posSyncProc.running = true;
            }
        }
    }

    // Unified Dynamic Island Now Playing View (Strictly aligned to 158px album art height: nothing above or below!)
    Item {
        anchors.fill: parent

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 17
            anchors.bottomMargin: 17
            spacing: 18

            // Left: Spacer for ControlCenter's Persistent Floating Album Artwork (158x158, radius 26)
            Item {
                id: albumCoverSlot
                Layout.preferredWidth: 158
                Layout.preferredHeight: 158
                Layout.alignment: Qt.AlignVCenter
            }

            // Right: Track Metadata, Inline Wavy Timeline & Transport Controls (exactly 158px tall to match album art)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 158
                Layout.maximumHeight: 158
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                // 1. Multi-player switcher row (ONLY shown when >1 media app is playing/active)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    visible: mediaTab.playerCount > 1
                    spacing: 8

                    Rectangle {
                        Layout.preferredHeight: 22
                        implicitWidth: idRow.implicitWidth + 16
                        radius: 11
                        color: idLg.isLiquidActive ? "transparent" : Theme.glassCard
                        border.color: Theme.glassBorder
                        border.width: idLg.isLiquidActive ? 0 : 1

                        LiquidGlassSurface {
                            id: idLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: 11
                        }

                        RowLayout {
                            id: idRow
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "󰎈"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: Theme.subtext
                            }

                            Text {
                                text: (mediaTab.player && mediaTab.player.identity) ? String(mediaTab.player.identity) : "Player"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.text
                                opacity: mediaTab.sourceSwitchOpacity
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Multi-player switcher
                    RowLayout {
                        spacing: 3

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: prevPLg.isLiquidActive ? "transparent" : (prevPBtn.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                            border.color: Theme.glassBorder
                            border.width: prevPLg.isLiquidActive ? 0 : 1
                            scale: prevPBtn.pressed ? 0.88 : (prevPBtn.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }

                            LiquidGlassSurface {
                                id: prevPLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 9
                                hovered: prevPBtn.containsMouse
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font.family: Theme.iconFont
                                font.pixelSize: 10
                                color: prevPBtn.containsMouse ? Theme.text : Theme.subtext
                                Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                            }

                            MouseArea {
                                id: prevPBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mediaTab.switchPlayerSource(-1)
                            }
                        }

                        Text {
                            text: (mediaTab.playerIndex + 1) + "/" + mediaTab.playerCount
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                            color: Theme.textDim
                            opacity: mediaTab.sourceSwitchOpacity
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: nextPLg.isLiquidActive ? "transparent" : (nextPBtn.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                            border.color: Theme.glassBorder
                            border.width: nextPLg.isLiquidActive ? 0 : 1
                            scale: nextPBtn.pressed ? 0.88 : (nextPBtn.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(170, 120) } }

                            LiquidGlassSurface {
                                id: nextPLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 9
                                hovered: nextPBtn.containsMouse
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: Theme.iconFont
                                font.pixelSize: 10
                                color: nextPBtn.containsMouse ? Theme.text : Theme.subtext
                                Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                            }

                            MouseArea {
                                id: nextPBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mediaTab.switchPlayerSource(1)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Spacer for ControlCenter's Persistent Floating Waveform when switcher row is shown
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 20
                    }
                }

                Item {
                    Layout.preferredHeight: 6
                    visible: mediaTab.playerCount > 1
                }

                // 2. Spacer for ControlCenter's Persistent Floating Track Title & Artist (and Waveform when single player)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: mediaTab.playerCount > 1 ? 42 : 48
                }

                Item { Layout.fillHeight: true }

                // 3. Inline Scrubber Bar with Tabular Timestamps
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 8

                    Text {
                        text: mediaTab.formatTime(mediaTab.realtimePosition)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: Theme.textDim
                    }

                    Item {
                        id: timelineTrackSlot
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24

                        readonly property real trackPad: 5
                        readonly property real trackSpan: Math.max(0, width - trackPad * 2)
                        readonly property real headX: trackPad + trackSpan * mediaTab.progress

                        Rectangle {
                            x: timelineTrackSlot.trackPad
                            y: (parent.height - height) / 2
                            width: timelineTrackSlot.trackSpan
                            height: 3.5
                            radius: 1.75
                            color: Theme.lightMode ? Qt.rgba(20 / 255, 22 / 255, 30 / 255, 0.20) : Qt.rgba(1.0, 1.0, 1.0, 0.22)
                        }

                        Rectangle {
                            x: timelineTrackSlot.trackPad
                            y: (parent.height - height) / 2
                            width: Math.max(0, timelineTrackSlot.trackSpan * mediaTab.progress)
                            height: 3.5
                            radius: 1.75
                            color: Theme.lightMode ? "#181920" : "#ffffff"
                            visible: mediaTab.progress > 0.001
                        }

                        Rectangle {
                            width: 11
                            height: 11
                            radius: 5.5
                            x: Math.max(timelineTrackSlot.trackPad, Math.min(parent.width - timelineTrackSlot.trackPad, timelineTrackSlot.headX)) - width / 2
                            y: (parent.height - height) / 2
                            color: Theme.lightMode ? "#181920" : "#ffffff"
                            visible: mediaTab.trackLength > 0
                        }

                        MouseArea {
                            id: scrubberMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            function seekFromMouse(mx) {
                                if (mediaTab.player && mediaTab.trackLength > 0) {
                                    const ratio = Math.max(0, Math.min(1.0, (mx - timelineTrackSlot.trackPad) / Math.max(1, timelineTrackSlot.trackSpan)));
                                    const targetSec = ratio * mediaTab.trackLength;
                                    mediaTab.basePosSec = targetSec;
                                    mediaTab.lastSyncMs = Date.now();
                                    mediaTab.realtimePosition = targetSec;
                                    mediaTab.player.position = mediaTab.player.length > 100000 ? (targetSec * 1000000) : targetSec;
                                }
                            }

                            onClicked: mouse => seekFromMouse(mouse.x)
                            onPositionChanged: mouse => {
                                if (pressed) seekFromMouse(mouse.x);
                            }
                        }
                    }

                    Text {
                        text: mediaTab.formatTime(mediaTab.trackLength)
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                        color: Theme.textDim
                    }
                }

                Item { Layout.preferredHeight: 8 }

                // 4. Centered Transport Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Item { Layout.fillWidth: true }

                    GlassBox {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        cornerRadius: 18
                        hovered: mPrev.containsMouse
                        pressed: mPrev.pressed

                        Text {
                            anchors.centerIn: parent
                            text: "󰒮"
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: Theme.text
                        }

                        MouseArea {
                            id: mPrev
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mediaTab.player) mediaTab.player.previous()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 22
                        color: (mPlayLg.isLiquidActive && !mediaTab.isPlaying)
                            ? "transparent"
                            : (mediaTab.isPlaying ? Theme.sliderFill : (mPlay.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard))
                        border.color: (mediaTab.isPlaying || mPlayLg.isLiquidActive) ? "transparent" : (mPlay.containsMouse ? Theme.glassHighlight : Theme.glassBorder)
                        border.width: (mediaTab.isPlaying || mPlayLg.isLiquidActive) ? 0 : 1
                        scale: mPlay.pressed ? 0.90 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        LiquidGlassSurface {
                            id: mPlayLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: 22
                            visible: !mediaTab.isPlaying
                            hovered: mPlay.containsMouse
                        }

                        Text {
                            anchors.centerIn: parent
                            text: mediaTab.isPlaying ? "󰏤" : "󰐊"
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: mediaTab.isPlaying ? Theme.sliderFillFg : Theme.text
                        }

                        MouseArea {
                            id: mPlay
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mediaTab.player) mediaTab.player.togglePlaying()
                        }
                    }

                    GlassBox {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        cornerRadius: 18
                        hovered: mNext.containsMouse
                        pressed: mNext.pressed

                        Text {
                            anchors.centerIn: parent
                            text: "󰒭"
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                            color: Theme.text
                        }

                        MouseArea {
                            id: mNext
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mediaTab.player) mediaTab.player.next()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
