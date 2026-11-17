import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import ".."
import "./cc"

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

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-frame"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    // 100% click-through so windows, bar widgets, and triggers work normally
    mask: Region {}

    readonly property real w: root.width
    readonly property real h: root.height

    // Floating full-pill top bar bounds
    readonly property real barX: Theme.barMarginX
    readonly property real barRightX: Math.max(barX + barR * 2 + 20, w - Theme.barMarginX)
    readonly property real barTopY: Theme.barTopGap
    readonly property real topT: Theme.barBottomY
    readonly property real barR: Theme.barRadius

    readonly property bool isMainMonitor: ShellState.isMainScreen(root.screen)
    readonly property string screenName: root.screen ? String(root.screen.name || "") : Theme.mainMonitorName
    readonly property bool ownsActivePanel: root.screenName === ShellState.activeMonitorName

    function syncMainScreenBounds() {
        if (root.w > 0 && root.h > 0) {
            const sx = root.screen ? Number(root.screen.x || 0) : 0;
            const sy = root.screen ? Number(root.screen.y || 0) : 0;
            ShellState.setMonitorGeometry(root.screenName, sx, sy, root.w, root.h);
        }
    }

    Component.onCompleted: syncMainScreenBounds()
    onWChanged: syncMainScreenBounds()
    onHChanged: syncMainScreenBounds()

    // Shared per-monitor offscreen compositor (wallpaper + live app windows on this monitor) feeding Liquid Glass on all capsules
    DesktopCaptureSource {
        id: desktopCap
        active: ShellState.liquidGlassEnabled && !ShellState.lockVisualOpen
        targetScreen: root.screen
        sceneWidth: root.w
        sceneHeight: root.h
    }

    Connections {
        target: ShellState
        function onControlCenterOpenChanged() {
            if (root.ownsActivePanel && ShellState.controlCenterOpen) {
                ShellState.scheduleDesktopRefresh(5);
                desktopCap.refreshNow();
            }
        }
        function onSysMenuOpenChanged() {
            if (root.ownsActivePanel && ShellState.sysMenuOpen) {
                ShellState.scheduleDesktopRefresh(5);
                desktopCap.refreshNow();
            }
        }
        function onNotifCenterOpenChanged() {
            if (root.ownsActivePanel && ShellState.notifCenterOpen) {
                ShellState.scheduleDesktopRefresh(5);
                desktopCap.refreshNow();
            }
        }
        function onWeatherOpenChanged() {
            if (root.ownsActivePanel && ShellState.weatherOpen) {
                ShellState.scheduleDesktopRefresh(5);
                desktopCap.refreshNow();
            }
        }
        function onIsFloatingModalModeChanged() {
            if (root.ownsActivePanel && ShellState.isFloatingModalMode) {
                ShellState.scheduleDesktopRefresh(5);
                desktopCap.refreshNow();
            }
        }
        function onCenterIslandModeChanged() {
            if (root.ownsActivePanel) desktopCap.triggerSettle();
        }
        function onLeftIslandModeChanged() {
            if (root.ownsActivePanel) desktopCap.triggerSettle();
        }
        function onRightIslandModeChanged() {
            if (root.ownsActivePanel) desktopCap.triggerSettle();
        }
        function onDesktopLayoutRevChanged() {
            if (root.ownsActivePanel) desktopCap.triggerSettle();
        }
    }

    readonly property bool liquidGlassReady: ShellState.liquidGlassEnabled && desktopCap.ready

    // Reusable helper: standard dark translucent gradient shown when Liquid Glass is disabled or on secondary monitors
    component StandardCapsuleFill: Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.islandTopColor }
            GradientStop { position: 0.62; color: Theme.islandMidColor }
            GradientStop { position: 1.0; color: Theme.islandBottomColor }
        }
        border.width: 1
        border.color: Theme.borderStroke
    }

    // ================= 3 MORPHING BAR ISLANDS + CENTER DYNAMIC ISLAND =================
    // 1. Left Morphing Capsule (Arch + Workspaces + Scratchpads -> morphs in-place into System Menu)
    Rectangle {
        id: leftCapsule
        x: root.barX
        y: root.barTopY
        width: root.ownsActivePanel ? ShellState.leftIslandWidth : ShellState.getSecondaryBarWidth(root.screenName, "left", ShellState.leftIslandBaseWidth)
        height: root.ownsActivePanel ? ShellState.leftIslandHeight : Theme.barHeight
        radius: root.ownsActivePanel ? ShellState.leftIslandRadius : root.barR
        color: "transparent"
        border.width: 0

        StandardCapsuleFill {
            visible: !root.liquidGlassReady
        }

        LiquidGlassEffect {
            anchors.fill: parent
            visible: root.liquidGlassReady
            desktopSource: desktopCap.textureSource
            screenX: leftCapsule.x
            screenY: leftCapsule.y
            screenW: leftCapsule.width
            screenH: leftCapsule.height
            cornerRadius: leftCapsule.radius
            screenWidth: root.w
            screenHeight: root.h
        }

        BottomGlassWave {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: parent.radius
            intensity: 1.0
            active: !ShellState.liquidGlassEnabled && ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && root.ownsActivePanel && (ShellState.sysMenuOpen || ShellState.leftIslandHeight > Theme.barHeight + 2)
        }
    }

    // 2. Center Dynamic Island (Active Window / Live Media -> morphs into Volume/Power/Notif/Control Center/Floating Modals)
    Rectangle {
        id: centerCapsule
        visible: root.isMainMonitor || ShellState.secondaryFullBar
        width: root.ownsActivePanel ? ShellState.centerIslandWidth : ShellState.getSecondaryBarWidth(root.screenName, "center", ShellState.centerIslandBaseWidth)
        height: root.ownsActivePanel ? ShellState.centerIslandHeight : Theme.barHeight
        x: (root.w - width) / 2
        y: root.ownsActivePanel ? ShellState.centerIslandY : root.barTopY
        radius: root.ownsActivePanel ? ShellState.centerIslandRadius : root.barR
        color: "transparent"
        border.width: 0

        StandardCapsuleFill {
            visible: !root.liquidGlassReady
        }

        LiquidGlassEffect {
            anchors.fill: parent
            visible: root.liquidGlassReady
            desktopSource: desktopCap.textureSource
            screenX: centerCapsule.x
            screenY: centerCapsule.y
            screenW: centerCapsule.width
            screenH: centerCapsule.height
            cornerRadius: centerCapsule.radius
            screenWidth: root.w
            screenHeight: root.h
        }

        // Extra frosted matte readability surface when Settings or Shortcuts is open
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: (root.ownsActivePanel && (ShellState.centerIslandMode === "settings" || ShellState.centerIslandMode === "cheatSheet")) ? 1.0 : 0.0
            visible: opacity > 0.005
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.lightMode ? Qt.rgba(0.95, 0.96, 0.99, 0.88) : Qt.rgba(0.06, 0.07, 0.10, 0.88) }
                GradientStop { position: 1.0; color: Theme.lightMode ? Qt.rgba(0.90, 0.92, 0.97, 0.94) : Qt.rgba(0.04, 0.05, 0.08, 0.93) }
            }
            border.width: 1
            border.color: Theme.glassCardBorder
            Behavior on opacity { NumberAnimation { duration: ShellState.animDur(260, 200); easing.type: ShellState.animPrimaryEase } }
        }

        readonly property bool isCenterPrimaryWaveMode: ShellState.centerIslandMode === "mediaToast"
            || ShellState.centerIslandMode === "ccMedia"
            || ShellState.centerIslandMode === "ccQuick"
        readonly property bool isCenterUtilityWaveMode: ShellState.centerIslandMode === "launcher"
            || ShellState.centerIslandMode === "clipboard"
            || ShellState.centerIslandMode === "settings"
            || ShellState.centerIslandMode === "cheatSheet"

        BottomGlassWave {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: parent.radius
            intensity: 1.0
            active: ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && root.ownsActivePanel && ShellState.centerIslandHeight > Theme.barHeight + 2
                && (parent.isCenterPrimaryWaveMode || parent.isCenterUtilityWaveMode)
                && (!ShellState.liquidGlassEnabled || ShellState.centerIslandMode === "mediaToast")
        }
    }

    // 3. Right Morphing Capsule (Tray + Weather + Battery + Clock + Bell -> morphs into Notification Center / Weather)
    Rectangle {
        id: rightCapsule
        visible: root.isMainMonitor || ShellState.secondaryFullBar
        width: root.ownsActivePanel ? ShellState.rightIslandWidth : ShellState.getSecondaryBarWidth(root.screenName, "right", ShellState.rightIslandBaseWidth)
        height: root.ownsActivePanel ? ShellState.rightIslandHeight : Theme.barHeight
        x: root.barRightX - width
        y: root.barTopY
        radius: root.ownsActivePanel ? ShellState.rightIslandRadius : root.barR
        color: "transparent"
        border.width: 0

        // Full-height animated Honor-style weather sky shader (stretches from top of bar to bottom of panel)
        readonly property bool weatherSkyActive: root.ownsActivePanel && (ShellState.weatherOpen || rightCapsule.skyProgress > 0.005 || (ShellState.rightIslandOwner === "weather" && ShellState.rightIslandHeight > Theme.barHeight + 0.5))

        StandardCapsuleFill {
            visible: !root.liquidGlassReady
        }

        LiquidGlassEffect {
            anchors.fill: parent
            visible: root.liquidGlassReady
            desktopSource: desktopCap.textureSource
            screenX: rightCapsule.x
            screenY: rightCapsule.y
            screenW: rightCapsule.width
            screenH: rightCapsule.height
            cornerRadius: rightCapsule.radius
            screenWidth: root.w
            screenHeight: root.h
        }
        property real skyProgress: 0.0
        onSkyProgressChanged: if (root.ownsActivePanel) ShellState.weatherSkyProgress = skyProgress
        NumberAnimation {
            id: skyFadeAnim
            target: rightCapsule
            property: "skyProgress"
            duration: 210
            easing.type: Easing.InOutCubic
            onRunningChanged: {
                if (!running && !ShellState.weatherOpen) {
                    rightCapsule.skyProgress = 0.0;
                }
            }
        }

        function syncWeatherSkyFade() {
            if (!root.ownsActivePanel) {
                skyFadeAnim.stop();
                rightCapsule.skyProgress = 0.0;
                return;
            }
            const target = ShellState.weatherOpen ? 1.0 : 0.0;
            if (Math.abs(rightCapsule.skyProgress - target) < 0.001 && !skyFadeAnim.running) {
                rightCapsule.skyProgress = target;
                return;
            }
            skyFadeAnim.stop();
            skyFadeAnim.from = rightCapsule.skyProgress;
            skyFadeAnim.to = target;
            skyFadeAnim.duration = ShellState.weatherOpen ? 240 : 200;
            skyFadeAnim.easing.type = ShellState.weatherOpen ? Easing.OutCubic : Easing.InOutCubic;
            skyFadeAnim.restart();
        }

        onVisibleChanged: if (!visible) { skyFadeAnim.stop(); skyProgress = 0.0; }

        property real introProgress: 0.0
        onIntroProgressChanged: if (root.ownsActivePanel) ShellState.weatherSkyIntro = introProgress
        NumberAnimation {
            id: skyIntroAnim
            target: rightCapsule
            property: "introProgress"
            from: 0.0
            to: 1.0
            duration: 820
            easing.type: Easing.OutCubic
        }

        Connections {
            target: ShellState
            function onWeatherOpenChanged() {
                rightCapsule.syncWeatherSkyFade();
                if (ShellState.weatherOpen && root.ownsActivePanel) {
                    skyIntroAnim.restart();
                }
            }
            function onWeatherDebugModeChanged() {
                if (ShellState.weatherOpen && root.ownsActivePanel) {
                    skyIntroAnim.restart();
                }
            }
        }

        Connections {
            target: root
            function onOwnsActivePanelChanged() {
                rightCapsule.syncWeatherSkyFade();
            }
        }

        property real skyShaderTime: 0.0
        onSkyShaderTimeChanged: if (root.ownsActivePanel) ShellState.weatherSkyTime = skyShaderTime
        NumberAnimation on skyShaderTime {
            from: 0.0
            to: 3600.0
            duration: 3600000
            loops: Animation.Infinite
            running: rightCapsule.weatherSkyActive
        }

        WeatherSkyBackdrop {
            anchors.fill: parent
            visible: rightCapsule.weatherSkyActive && rightCapsule.skyProgress > 0.005
            opacity: rightCapsule.skyProgress
            skyTime: rightCapsule.skyShaderTime
            introProgress: rightCapsule.introProgress
            cornerRadius: rightCapsule.radius
        }

        // Ambient music wave on Right Island panels (Notification Center) — explicitly disabled on Weather and Liquid Glass
        BottomGlassWave {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            panelWidth: parent.width
            panelHeight: parent.height
            cornerRadius: parent.radius
            intensity: 1.0
            active: !ShellState.liquidGlassEnabled && ShellState.panelWavesEnabled && ShellState.isAnyMediaPlaying && root.ownsActivePanel && !rightCapsule.weatherSkyActive && (ShellState.notifCenterOpen || (ShellState.rightIslandOwner === "notifCenter" && ShellState.rightIslandHeight > Theme.barHeight + 2))
        }
    }

    // Per-monitor Identify OSD badge (KDE/GNOME style)
    Rectangle {
        id: identifyPill
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44
        anchors.horizontalCenter: parent.horizontalCenter
        width: identifyRow.implicitWidth + 32
        height: 44
        radius: 22
        opacity: ShellState.identifyMonitorsOpen ? 1.0 : 0.0
        visible: opacity > 0.01
        scale: ShellState.identifyMonitorsOpen ? 1.0 : 0.90
        color: root.liquidGlassReady ? "transparent" : Theme.glassSurfaceActive
        border.width: root.liquidGlassReady ? 0 : 1
        border.color: Theme.glassHighlight

        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(220, 140); easing.type: ShellState.animPrimaryEase } }
        Behavior on scale { NumberAnimation { duration: ShellState.animDur(240, 160); easing.type: ShellState.animPrimaryEase } }

        LiquidGlassEffect {
            anchors.fill: parent
            visible: root.liquidGlassReady && identifyPill.visible
            desktopSource: desktopCap.textureSource
            screenX: identifyPill.x
            screenY: identifyPill.y
            screenW: identifyPill.width
            screenH: identifyPill.height
            cornerRadius: 22
            screenWidth: root.w
            screenHeight: root.h
            tintColor: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.34) : Qt.rgba(0.10, 0.12, 0.16, 0.56)
            rimColor: Theme.glassHighlight
        }

        Row {
            id: identifyRow
            anchors.centerIn: parent
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍹"
                font.family: Theme.iconFont
                font.pixelSize: 16
                color: Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.screenName + (root.ownsActivePanel ? " (Primary)" : "") + "  •  " + Math.round(root.w) + "×" + Math.round(root.h)
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Theme.text
            }
        }
    }
}
