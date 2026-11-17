import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import ".."

PanelWindow {
    id: root

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

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-lockscreen"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: (ShellState.locked && root.isPrimaryLock) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: -1

    color: "transparent"
    // Allocate fullscreen layer buffers only while locking, active, or docking back into the island
    visible: root.isLockVisible

    ShortcutInhibitor {
        window: root
        enabled: ShellState.locked && root.isPrimaryLock
    }

    readonly property string screenName: root.screen ? String(root.screen.name || "") : Theme.mainMonitorName
    readonly property bool isPrimaryLock: root.screenName === ShellState.activeMonitorName || Quickshell.screens.length <= 1
    readonly property real screenW: root.width > 0 ? root.width : (root.screen ? root.screen.width : ShellState.mainScreenWidth)
    readonly property real screenH: root.height > 0 ? root.height : (root.screen ? root.screen.height : ShellState.mainScreenHeight)
    readonly property string username: Quickshell.env("USER") || "User"
    readonly property string displayName: username.length > 0 ? (username.charAt(0).toUpperCase() + username.slice(1)) : "User"

    readonly property bool isDockSettled: !ShellState.lockVisualOpen
        && ShellState.centerIslandHeight <= Theme.barHeight + 2
        && ShellState.centerIslandY <= Theme.barTopGap + 2

    // Only true while Lock Screen itself owns the Dynamic Island (or is actively collapsing from an unlock)
    property bool isLockOwned: false

    // Secondary monitor mirror progress (primary follows ShellState.centerIsland* 1:1)
    property real secProgress: 0.0

    readonly property bool isLockVisible: ShellState.locked
        || ShellState.lockVisualOpen
        || root.isLockOwned

    onIsDockSettledChanged: {
        if (root.isLockOwned && !ShellState.locked && !ShellState.lockVisualOpen && root.isPrimaryLock && root.isDockSettled) {
            root.isLockOwned = false;
        }
    }

    onSecProgressChanged: {
        if (root.isLockOwned && !ShellState.locked && !ShellState.lockVisualOpen && !root.isPrimaryLock && root.secProgress <= 0.002 && !secCollapseAnim.running) {
            root.isLockOwned = false;
        }
    }

    // Live bounding geometry: primary screen physically rides ShellState's Center Dynamic Island;
    // secondary screens expand identically out of their own top-center Dynamic Island capsule.
    readonly property real secPillW: Math.max(120, ShellState.getSecondaryBarWidth(root.screenName, "center", ShellState.centerIslandBaseWidth))
    readonly property real activeW: root.isPrimaryLock
        ? Math.max(1, ShellState.centerIslandWidth)
        : Math.max(1, root.secPillW + (root.screenW - root.secPillW) * root.secProgress)
    readonly property real activeH: root.isPrimaryLock
        ? Math.max(1, ShellState.centerIslandHeight)
        : Math.max(1, Theme.barHeight + (root.screenH - Theme.barHeight) * root.secProgress)
    readonly property real activeX: Math.round((root.screenW - root.activeW) / 2)
    readonly property real activeY: root.isPrimaryLock
        ? ShellState.centerIslandY
        : (Theme.barTopGap * (1.0 - root.secProgress))
    readonly property real activeR: root.isPrimaryLock
        ? Math.max(0, Math.min(root.activeH / 2, ShellState.centerIslandRadius))
        : Math.max(0, Math.min(root.activeH / 2, Theme.barRadius * (1.0 - root.secProgress)))

    // Overall normalized open ratio (0 at bar pill, 1 at full screen)
    readonly property real openProgress: root.screenH > Theme.barHeight + 1
        ? Math.max(0.0, Math.min(1.0, (root.activeH - Theme.barHeight) / (root.screenH - Theme.barHeight)))
        : 0.0

    function smoothstep01(val) {
        const t = Math.min(1.0, Math.max(0.0, val));
        return t * t * (3.0 - 2.0 * t);
    }

    // Island-coupled container & content crossfades (matches IslandFloatPanel's silky curve)
    readonly property real effectiveSurfaceOpacity: ShellState.lockVisualOpen
        ? root.smoothstep01(root.openProgress / 0.24)
        : root.smoothstep01(root.openProgress / 0.34)

    readonly property real effectiveContentOpacity: ShellState.lockVisualOpen
        ? root.smoothstep01((root.openProgress - 0.14) / 0.56)
        : root.smoothstep01((root.openProgress - 0.32) / 0.52)

    property string avatarPath: ""
    property bool authenticating: false
    property bool unlockingSuccess: false
    property string authError: ""
    property string pendingPassword: ""
    property real shakeOffset: 0
    property real spinnerAngle: 0

    Process {
        id: avatarProbeProc
        command: ["sh", "-c", "for p in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$USER\"; do [ -s \"$p\" ] && { printf '%s' \"$p\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.avatarPath = text.trim();
            }
        }
    }

    Component.onCompleted: avatarProbeProc.running = true

    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // Real Linux PAM authentication (/etc/pam.d/vlock -> pam_unix.so + unix_chkpwd)
    PamContext {
        id: pam
        config: "vlock"
        user: root.username

        onPamMessage: {
            if (responseRequired) {
                const pw = root.pendingPassword;
                root.pendingPassword = "";
                pam.respond(pw);
            } else if (messageIsError && message.length > 0 && root.authenticating) {
                root.authError = message;
            }
        }

        onCompleted: result => {
            root.authenticating = false;
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                passInput.text = "";
                root.authError = "";
                root.unlockingSuccess = true;
                unlockCommitTimer.restart();
            } else {
                passInput.text = "";
                root.authError = (result === PamResult.MaxTries)
                    ? "Too many attempts — try again"
                    : "Incorrect password";
                shakeAnim.restart();
                focusRestoreTimer.restart();
            }
        }

        onError: err => {
            root.authenticating = false;
            root.pendingPassword = "";
            root.authError = "Auth error: " + PamError.toString(err);
            shakeAnim.restart();
            focusRestoreTimer.restart();
        }
    }

    function submitPassword() {
        if (!ShellState.locked || root.authenticating || root.unlockingSuccess) return;
        const pw = passInput.text;
        if (pw.length === 0) {
            root.authError = "Enter your password";
            shakeAnim.restart();
            focusRestoreTimer.restart();
            return;
        }
        root.authError = "";
        root.pendingPassword = pw;
        root.authenticating = true;
        if (!pam.start()) {
            root.authenticating = false;
            root.pendingPassword = "";
            root.authError = "Unable to start authentication";
            shakeAnim.restart();
            focusRestoreTimer.restart();
        }
    }

    Timer {
        id: unlockCommitTimer
        interval: 150
        repeat: false
        onTriggered: ShellState.unlockScreen()
    }

    Timer {
        id: focusRestoreTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (ShellState.locked && root.isPrimaryLock) {
                passInput.forceActiveFocus();
            }
        }
    }

    NumberAnimation {
        id: secExpandAnim
        target: root
        property: "secProgress"
        to: 1.0
        duration: ShellState.animDur(560, 440)
        easing.type: ShellState.animPrimaryEase
    }

    NumberAnimation {
        id: secCollapseAnim
        target: root
        property: "secProgress"
        to: 0.0
        duration: ShellState.animDur(480, 360)
        easing.type: Easing.InOutCubic
    }

    Connections {
        target: ShellState
        function onCenterIslandModeChanged() {
            if (root.isLockOwned && !ShellState.locked && !ShellState.lockVisualOpen
                && ShellState.centerIslandMode !== "collapsed" && ShellState.centerIslandMode !== "lock") {
                root.isLockOwned = false;
            }
        }
        function onLockedChanged() {
            if (ShellState.locked) {
                secCollapseAnim.stop();
                root.isLockOwned = true;
                root.unlockingSuccess = false;
                root.authenticating = false;
                root.pendingPassword = "";
                root.authError = "";
                passInput.text = "";
                avatarProbeProc.running = true;
                if (!root.isPrimaryLock) {
                    secExpandAnim.restart();
                } else {
                    root.secProgress = 1.0;
                }
                focusRestoreTimer.restart();
            } else {
                secExpandAnim.stop();
                if (pam.active) pam.abort();
                root.authenticating = false;
                root.pendingPassword = "";
                passInput.text = "";
                if (!root.isPrimaryLock) {
                    secCollapseAnim.restart();
                } else {
                    root.secProgress = 0.0;
                    if (root.isDockSettled) {
                        root.isLockOwned = false;
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeOffset"; to: -13; duration: 48; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 12; duration: 64; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -9; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 6; duration: 54; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -3; duration: 46; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 42; easing.type: Easing.OutQuad }
    }

    NumberAnimation on spinnerAngle {
        from: 0
        to: 360
        duration: 850
        loops: Animation.Infinite
        running: root.authenticating
    }

    // Offscreen wallpaper blur source (cached once at half-res so dynamic island morph never re-blurs per frame)
    Item {
        id: wallBlurHost
        width: Math.max(1, root.screenW)
        height: Math.max(1, root.screenH)
        visible: false

        Image {
            id: lockBgImg
            anchors.fill: parent
            source: (root.isLockVisible && ShellState.wallpaperPath) ? ("file://" + ShellState.wallpaperPath) : ""
            sourceSize.width: Math.max(1, Math.round(root.screenW * 0.5))
            sourceSize.height: Math.max(1, Math.round(root.screenH * 0.5))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        FastBlur {
            id: blurredWallFx
            anchors.fill: parent
            source: lockBgImg
            radius: 40
            transparentBorder: false
            cached: true
            visible: lockBgImg.status === Image.Ready
        }
    }

    // Active Visual Host (hidden completely at rest when unlocked & docked in the top bar)
    Item {
        anchors.fill: parent
        visible: root.isLockVisible

        // Container expanding physically from the top-center Dynamic Island to fill the entire display
        Item {
            id: lockBox
            x: root.activeX
            y: root.activeY
            width: root.activeW
            height: root.activeH
            clip: true

            readonly property bool useRoundMask: root.activeR > 0.5 || width < root.screenW - 1 || height < root.screenH - 1

            Rectangle {
                id: lockPillMask
                anchors.fill: parent
                radius: root.activeR
                visible: false
            }

            Item {
                id: lockScene
                anchors.fill: parent
                opacity: root.effectiveSurfaceOpacity
                layer.enabled: lockBox.useRoundMask
                layer.effect: OpacityMask {
                    maskSource: lockPillMask
                }

                // 1. Blurred Wallpaper Backdrop + Clean Frosted Vignette (anchored in screen-space so portal opens over it without sliding)
                Item {
                    id: bgCanvas
                    x: -lockBox.x
                    y: -lockBox.y
                    width: root.screenW
                    height: root.screenH

                    ShaderEffectSource {
                        anchors.fill: parent
                        sourceItem: blurredWallFx
                        live: lockBgImg.status === Image.Ready
                        visible: lockBgImg.status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#090b10"
                        visible: lockBgImg.status !== Image.Ready
                    }

                    // Clean frosted dark depth gradient (no distracting radial circle)
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#7206080e" }
                            GradientStop { position: 0.55; color: "#88080a12" }
                            GradientStop { position: 1.0; color: "#c404050a" }
                        }
                    }
                }

                // 2. Fullscreen Lock UI Content (anchored to screen-space, native crisp vector font rendering)
                Item {
                    id: uiLayer
                    x: -lockBox.x
                    y: -lockBox.y
                    width: root.screenW
                    height: root.screenH
                    opacity: root.effectiveContentOpacity

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (ShellState.locked && !root.isPrimaryLock) {
                                ShellState.activeMonitorName = root.screenName;
                            }
                            if (root.isPrimaryLock) passInput.forceActiveFocus();
                        }
                    }

                    // Top Status & Active Keyboard Layout Capsule
                    RowLayout {
                        anchors.top: parent.top
                        anchors.topMargin: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Rectangle {
                            Layout.preferredHeight: 30
                            implicitWidth: lockBadgeRow.implicitWidth + 22
                            radius: 15
                            color: root.unlockingSuccess ? "#2830d158" : "#24ffffff"
                            border.width: 1
                            border.color: root.unlockingSuccess ? "#8030d158" : "#26ffffff"
                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            RowLayout {
                                id: lockBadgeRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: root.unlockingSuccess ? "󰄬" : "󰌾"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    color: root.unlockingSuccess ? "#30d158" : "#ffffff"
                                }
                                Text {
                                    text: root.unlockingSuccess ? "Unlocked" : "Locked"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#ffffff"
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 30
                            implicitWidth: kbLockRow.implicitWidth + 20
                            radius: 15
                            color: kbLockMouse.containsMouse ? "#32ffffff" : "#20ffffff"
                            border.width: 1
                            border.color: kbLockMouse.containsMouse ? "#48ffffff" : "#26ffffff"
                            scale: kbLockMouse.pressed ? 0.93 : (kbLockMouse.containsMouse ? 1.04 : 1.0)
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: kbLockRow
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "󰌌"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    color: Theme.accent
                                }
                                Text {
                                    text: ShellState.activeKeyboardLayout
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: "#f0ffffff"
                                }
                            }

                            MouseArea {
                                id: kbLockMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ShellState.nextKeyboardLayout();
                                    if (root.isPrimaryLock) passInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // Upper Crisp Big Clock & Date
                    ColumnLayout {
                        anchors.top: parent.top
                        anchors.topMargin: Math.max(82, parent.height * 0.13)
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4
                        transform: Translate {
                            y: (1.0 - root.effectiveContentOpacity) * -14
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.formatDate(sysClock.date, "dddd, MMMM d")
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.max(16, Math.min(22, root.screenH * 0.02))
                            font.weight: Font.Medium
                            font.letterSpacing: 0.4
                            renderType: Text.NativeRendering
                            color: "#dcffffff"
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Text {
                                text: Qt.formatTime(sysClock.date, ShellState.use24HourClock ? "HH:mm" : "hh:mm")
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.max(82, Math.min(126, root.screenH * 0.12))
                                font.weight: Font.Light
                                font.letterSpacing: -2
                                font.hintingPreference: Font.PreferNoHinting
                                renderType: Text.NativeRendering
                                color: "#ffffff"
                            }

                            Text {
                                visible: !ShellState.use24HourClock
                                Layout.alignment: Qt.AlignBottom
                                Layout.bottomMargin: 18
                                text: Qt.formatTime(sysClock.date, "AP")
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                font.weight: Font.Medium
                                renderType: Text.NativeRendering
                                color: "#b0ffffff"
                            }
                        }
                    }

                    // Center User Profile + Generic Avatar & Auth Field
                    ColumnLayout {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: Math.min(72, root.screenH * 0.065)
                        spacing: 14
                        transform: Translate {
                            y: (1.0 - root.effectiveContentOpacity) * 16
                        }

                        // Circular User Profile Avatar (uses ~/.face photo if present, or generic sleek user icon)
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: 92
                            height: 92

                            Rectangle {
                                anchors.centerIn: parent
                                width: 92
                                height: 92
                                radius: 46
                                color: "transparent"
                                border.width: 2
                                border.color: root.unlockingSuccess
                                    ? "#cc30d158"
                                    : (root.authError.length > 0
                                        ? "#ccff453a"
                                        : (passInput.text.length > 0 ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.78) : "#42ffffff"))
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }

                            Rectangle {
                                id: avatarDisc
                                anchors.centerIn: parent
                                width: 82
                                height: 82
                                radius: 41
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#36ffffff" }
                                    GradientStop { position: 1.0; color: "#28141822" }
                                }
                                border.width: 1
                                border.color: "#40ffffff"

                                // Generic minimalist user avatar silhouette (no initial letter)
                                Text {
                                    anchors.centerIn: parent
                                    visible: root.avatarPath.length === 0
                                    text: "󰀄"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 40
                                    color: "#ebffffff"
                                }

                                // Loaded user photo from ~/.face if present
                                Image {
                                    id: faceImg
                                    anchors.fill: parent
                                    source: root.avatarPath.length > 0 ? ("file://" + root.avatarPath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                    asynchronous: true
                                }

                                Rectangle {
                                    id: faceMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: faceImg
                                    maskSource: faceMask
                                    visible: root.avatarPath.length > 0 && faceImg.status === Image.Ready
                                }
                            }
                        }

                        // User Name
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.displayName
                                font.family: Theme.fontFamily
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                                color: "#ffffff"
                            }

                            Text {
                                visible: !root.isPrimaryLock
                                Layout.alignment: Qt.AlignHCenter
                                text: "Click here to enter password"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: "#90ffffff"
                            }
                        }

                        // Frosted Password Pill
                        Item {
                            visible: root.isPrimaryLock
                            Layout.alignment: Qt.AlignHCenter
                            width: 288
                            height: 46

                            Rectangle {
                                id: passPill
                                x: root.shakeOffset
                                width: parent.width
                                height: parent.height
                                radius: 23
                                color: root.unlockingSuccess
                                    ? "#2c30d158"
                                    : (root.authError.length > 0
                                        ? "#28ff453a"
                                        : (passInput.activeFocus ? "#30ffffff" : "#20ffffff"))
                                border.width: (passInput.activeFocus || root.authError.length > 0 || root.unlockingSuccess) ? 1.5 : 1
                                border.color: root.unlockingSuccess
                                    ? "#b030d158"
                                    : (root.authError.length > 0
                                        ? "#c0ff453a"
                                        : (passInput.activeFocus ? "#68ffffff" : "#32ffffff"))

                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on border.color { ColorAnimation { duration: 180 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 15
                                    anchors.rightMargin: 6
                                    spacing: 9

                                    Text {
                                        text: root.unlockingSuccess ? "󰄬" : "󰌋"
                                        font.family: Theme.iconFont
                                        font.pixelSize: 15
                                        color: root.unlockingSuccess ? "#30d158" : (root.authError.length > 0 ? "#ff6961" : "#b8ffffff")
                                    }

                                    TextInput {
                                        id: passInput
                                        Layout.fillWidth: true
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 14
                                        color: "#ffffff"
                                        selectionColor: Theme.accent
                                        echoMode: TextInput.Password
                                        passwordCharacter: "•"
                                        enabled: !root.authenticating && !root.unlockingSuccess
                                        focus: ShellState.locked && root.isPrimaryLock
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: root.authenticating ? "Verifying..." : "Enter password..."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 14
                                            color: "#85ffffff"
                                            visible: !passInput.text && !root.unlockingSuccess
                                        }

                                        onTextEdited: {
                                            if (root.authError.length > 0) root.authError = "";
                                        }

                                        Keys.onEscapePressed: {
                                            passInput.text = "";
                                            root.authError = "";
                                        }

                                        onAccepted: root.submitPassword()
                                    }

                                    // Submit Arrow / PAM Spinner / Success Check
                                    Rectangle {
                                        width: 34
                                        height: 34
                                        radius: 17
                                        color: root.unlockingSuccess
                                            ? "#30d158"
                                            : (unlockMouse.containsMouse && !root.authenticating ? "#ffffff" : "#2cffffff")
                                        scale: unlockMouse.pressed ? 0.90 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !root.authenticating
                                            text: root.unlockingSuccess ? "󰄬" : "󰁔"
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            color: root.unlockingSuccess
                                                ? "#ffffff"
                                                : (unlockMouse.containsMouse ? "#121214" : "#ffffff")
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: "transparent"
                                            border.width: 2
                                            border.color: "#40ffffff"
                                            visible: root.authenticating
                                            rotation: root.spinnerAngle

                                            Rectangle {
                                                width: 5
                                                height: 5
                                                radius: 2.5
                                                color: "#ffffff"
                                                anchors.top: parent.top
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.topMargin: -1
                                            }
                                        }

                                        MouseArea {
                                            id: unlockMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.submitPassword()
                                        }
                                    }
                                }
                            }
                        }

                        // Hint / Error Status Line
                        Text {
                            visible: root.isPrimaryLock
                            Layout.alignment: Qt.AlignHCenter
                            text: root.unlockingSuccess
                                ? "Welcome back"
                                : (root.authError.length > 0
                                    ? root.authError
                                    : (root.authenticating ? "Checking credentials..." : "Press Enter to unlock"))
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: root.authError.length > 0 ? Font.DemiBold : Font.Normal
                            color: root.unlockingSuccess
                                ? "#30d158"
                                : (root.authError.length > 0 ? "#ff6961" : "#80ffffff")
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    // 3. Bottom Minimal Power Actions Bar
                    RowLayout {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 32
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        Rectangle {
                            width: 42
                            height: 42
                            radius: 21
                            color: lockSuspMouse.containsMouse ? "#38ffffff" : "#1cffffff"
                            border.color: lockSuspMouse.containsMouse ? "#48ffffff" : "#2cffffff"
                            border.width: 1
                            scale: lockSuspMouse.pressed ? 0.91 : (lockSuspMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰒲"
                                font.family: Theme.iconFont
                                font.pixelSize: 17
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: lockSuspMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                            }
                        }

                        Rectangle {
                            width: 42
                            height: 42
                            radius: 21
                            color: lockRebMouse.containsMouse ? "#38ff9f0a" : "#1cffffff"
                            border.color: lockRebMouse.containsMouse ? "#60ff9f0a" : "#2cffffff"
                            border.width: 1
                            scale: lockRebMouse.pressed ? 0.91 : (lockRebMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰜉"
                                font.family: Theme.iconFont
                                font.pixelSize: 17
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: lockRebMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                            }
                        }

                        Rectangle {
                            width: 42
                            height: 42
                            radius: 21
                            color: lockPwrMouse.containsMouse ? Theme.red : "#1cffffff"
                            border.color: lockPwrMouse.containsMouse ? Theme.red : "#2cffffff"
                            border.width: 1
                            scale: lockPwrMouse.pressed ? 0.91 : (lockPwrMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰐥"
                                font.family: Theme.iconFont
                                font.pixelSize: 17
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: lockPwrMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                            }
                        }
                    }
                }
            }
        }
    }
}
