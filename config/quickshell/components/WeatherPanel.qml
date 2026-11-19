import QtQuick
import QtQuick.Layouts
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
    readonly property real h: Math.max(0, ShellState.rightIslandHeight - Theme.barHeight)
    readonly property real targetW: ShellState.targetWeatherWidth
    readonly property real targetH: Theme.weatherMaxHeight
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, (ShellState.smoothRightIslandHeight - Theme.barHeight) / Math.max(1, targetH)))
    readonly property real rightOffset: Theme.barMarginX
    readonly property bool isActiveRight: ShellState.weatherOpen || ShellState.rightIslandOwner === "weather"

    implicitWidth: Math.max(targetW, ShellState.targetNotifCenterWidth) + rightOffset + 48
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-weather"
    WlrLayershell.keyboardFocus: (ShellState.weatherOpen && !ShellState.weatherDebugOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: h > 0.5 && isActiveRight
    mask: Region { item: weatherContent }

    property bool hasEnteredPanel: false

    function iconColorFor(iconStr, descStr) {
        const d = (descStr || "").toLowerCase();
        const ic = iconStr || "";
        if (d.includes("thunder") || d.includes("t-storm") || ic === "󰖓" || ic === "󰙾") return "#FACC15";
        if (d.includes("snow") || ic === "󰖘" || ic === "󰼶") return "#BAE6FD";
        if (d.includes("rain") || d.includes("drizzle") || d.includes("shower") || ic === "󰖗" || ic === "󰖖" || ic === "󰼳") return "#38BDF8";
        if (d.includes("fog") || ic === "󰖑") return "#99F6E4";
        if (ic === "󰖔" || ic === "󰼱") return "#C7D2FE";
        if (d.indexOf("partly") !== -1 || d.indexOf("mostly") !== -1 || ic === "󰖕") return "#FDE047";
        if (d.indexOf("clear") !== -1 || ic === "󰖙") return "#FBBF24";
        return "#F8FAFC";
    }

    function parseNum(str, fallback) {
        if (str === undefined || str === null) return fallback;
        const m = String(str).match(/-?\d+/);
        return m ? Number(m[0]) : fallback;
    }

    Connections {
        target: ShellState
        function onWeatherOpenChanged() {
            root.hasEnteredPanel = false;
            closeDelayTimer.stop();
        }
        function onWeatherForecastChanged() {
            trendCanvas.requestPaint();
        }
    }

    HyprlandFocusGrab {
        active: ShellState.weatherOpen && !ShellState.weatherDebugOpen && root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: {
            ShellState.weatherOpen = false;
        }
    }

    Item {
        focus: ShellState.weatherOpen
        Keys.onEscapePressed: ShellState.weatherOpen = false
    }

    // Offscreen synced weather sky texture feeding Liquid Glass cards & refresh button (main sky background stays untouched)
    Item {
        width: 0
        height: 0
        clip: true
        visible: ShellState.liquidGlassEnabled && root.visible

        Item {
            id: weatherSkyScene
            x: 0
            y: 0
            width: Math.max(1, ShellState.rightIslandWidth)
            height: Math.max(1, ShellState.rightIslandHeight)

            WeatherSkyBackdrop {
                anchors.fill: parent
            }
        }
    }

    ShaderEffectSource {
        id: weatherSkySource
        visible: false
        sourceItem: weatherSkyScene
        hideSource: true
        live: ShellState.liquidGlassEnabled && root.visible
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(weatherSkyScene.width)), Math.max(1, Math.round(weatherSkyScene.height)))
    }

    // Aligned flush with ScreenFrame's Right Morphing Island (starts at y=0 immediately below the 38px bar header)
    Item {
        id: weatherContent
        readonly property bool liquidGlassHost: true
        readonly property var liquidSource: weatherSkySource
        readonly property bool liquidSourceReady: ShellState.liquidGlassEnabled && root.visible
        readonly property real liquidOriginX: -x
        readonly property real liquidOriginY: Theme.barHeight
        readonly property real liquidTexWidth: Math.max(1, ShellState.rightIslandWidth)
        readonly property real liquidTexHeight: Math.max(1, ShellState.rightIslandHeight)
        readonly property int liquidLayoutRev: Math.round(ShellState.rightIslandWidth + ShellState.smoothRightIslandHeight * 3 + ShellState.rightIslandDeformScaleY * 1000)

        x: root.width - root.rightOffset - ShellState.rightIslandWidth
        y: 0
        width: Math.max(1, ShellState.rightIslandWidth)
        height: Math.max(1, root.h)
        clip: true

        HoverHandler {
            id: panelHover
            onHoveredChanged: {
                if (hovered) {
                    root.hasEnteredPanel = true;
                    closeDelayTimer.stop();
                } else if (ShellState.weatherOpen && root.hasEnteredPanel && !ShellState.weatherDebugOpen) {
                    closeDelayTimer.restart();
                }
            }
        }

        Timer {
            id: closeDelayTimer
            interval: 280
            repeat: false
            onTriggered: {
                if (!panelHover.hovered && root.hasEnteredPanel && !ShellState.weatherDebugOpen) {
                    ShellState.weatherOpen = false;
                }
            }
        }

        Item {
            id: scaledBody
            width: root.targetW
            height: root.targetH
            anchors.top: parent.top
            anchors.right: parent.right
            opacity: ShellState.weatherOpen ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: ShellState.animDur(260, 160); easing.type: ShellState.animPrimaryEase } }

            transform: Scale {
                origin.x: root.targetW
                origin.y: 0
                xScale: ShellState.rightIslandWidth / Math.max(1, root.targetW)
                yScale: (0.72 + 0.28 * root.smoothHRatio) * ShellState.rightIslandDeformScaleY
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 8
                anchors.bottomMargin: 14
                spacing: 8

                // ================= 1. OPEN-SKY HONOR-STYLE HERO SECTION (FLOATING IN MOVING CLOUDS) =================
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 158
                    Layout.maximumHeight: 158

                    // Top bar: Optically Centered City Name, Right Circular Refresh Button
                    Item {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 30

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 1
                            text: ShellState.weatherCity || "Local Weather"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                        }

                        // Top-right Circular Glass Refresh Button (Honor style)
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: 13
                            color: wRefreshLg.isLiquidActive ? "transparent" : (refreshMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10))
                            border.color: Qt.rgba(1, 1, 1, 0.22)
                            border.width: wRefreshLg.isLiquidActive ? 0 : 1
                            scale: refreshMouse.pressed ? 0.90 : (refreshMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 120) } }

                            LiquidGlassSurface {
                                id: wRefreshLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 13
                                hovered: refreshMouse.containsMouse
                                frost: 0.55
                                restTint: Qt.rgba(0.92, 0.96, 1.0, 0.08)
                                hoverTint: Qt.rgba(1.0, 1.0, 1.0, 0.18)
                                restRim: Qt.rgba(1.0, 1.0, 1.0, 0.72)
                                hoverRim: Qt.rgba(1.0, 1.0, 1.0, 0.92)
                            }

                            Text {
                                id: wRefreshIcon
                                anchors.centerIn: parent
                                text: "󰑐"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: "#FFFFFF"
                                Behavior on rotation {
                                    NumberAnimation { duration: ShellState.animDur(420, 280); easing.type: ShellState.animPrimaryEase }
                                }
                            }

                            MouseArea {
                                id: refreshMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wRefreshIcon.rotation += 360;
                                    ShellState.weatherDebugMode = "";
                                    ShellState.refreshWeather();
                                }
                            }
                        }
                    }

                    // Optically Balanced Giant Temperature + High/Low + Condition Subtitle
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 30
                        spacing: 3

                        // Optically centered giant numeral: digits centered, degree symbol anchored to top-right
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tempDigits.implicitWidth
                            height: 62

                            Text {
                                id: tempDigits
                                anchors.centerIn: parent
                                text: (ShellState.weatherTempShort || "7°").replace("°", "")
                                font.family: Theme.fontFamily
                                font.pixelSize: 54
                                font.weight: Font.DemiBold
                                font.features: { "tnum": 1 }
                                color: "#FFFFFF"
                            }

                            Text {
                                anchors.left: tempDigits.right
                                anchors.leftMargin: 1
                                anchors.top: tempDigits.top
                                anchors.topMargin: 7
                                text: "°"
                                font.family: Theme.fontFamily
                                font.pixelSize: 28
                                font.weight: Font.DemiBold
                                color: "#FFFFFF"
                            }
                        }

                        // "High: 10°  Low: 7°"
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "High: " + (ShellState.weatherHigh || "9°") + "   Low: " + (ShellState.weatherLow || "1°")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.92)
                        }

                        // "Feels 3°C  •  Cloudy" (leaf removed, optically centered)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Feels " + (ShellState.weatherFeelsLike || "3°C") + "  •  " + (ShellState.weatherDesc || "Cloudy")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                        }
                    }
                }

                // ================= 2. TRANSLUCENT HOURLY WEATHER CARD =================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    Layout.maximumHeight: 92
                    radius: 18
                    color: wHourlyLg.isLiquidActive ? "transparent" : Qt.rgba(1.0, 1.0, 1.0, 0.09)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                    border.width: wHourlyLg.isLiquidActive ? 0 : 1

                    LiquidGlassSurface {
                        id: wHourlyLg
                        anchors.fill: parent
                        z: -1
                        cornerRadius: 18
                        frost: 0.55
                        restTint: Qt.rgba(0.92, 0.96, 1.0, 0.07)
                        restRim: Qt.rgba(1.0, 1.0, 1.0, 0.68)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 4

                        // Card Header: "Hourly weather" + Humidity & Wind summary
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "󰂚"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: Qt.rgba(1, 1, 1, 0.72)
                            }

                            Text {
                                text: "Hourly weather"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.76)
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "󰖎 " + (ShellState.weatherHumidity || "90%") + "   󰖝 " + (ShellState.weatherWind || "15 km/h")
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.68)
                            }
                        }

                        // 5 Hourly Slots: Now, 23:00, 00:00, 01:00, 02:00
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            Repeater {
                                model: ShellState.weatherHourly

                                delegate: Item {
                                    id: hrSlot
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property string slotIcon: (index === 0 && ShellState.weatherDebugMode.length > 0)
                                        ? ShellState.weatherIcon
                                        : (modelData.icon || "󰖐")
                                    readonly property string slotDesc: (index === 0 && ShellState.weatherDebugMode.length > 0)
                                        ? ShellState.weatherDesc
                                        : (modelData.desc || "Cloudy")

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 2

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: hrSlot.modelData.time || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: hrSlot.index === 0 ? Font.Bold : Font.Medium
                                            color: hrSlot.index === 0 ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.84)
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: hrSlot.slotIcon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 16
                                            color: root.iconColorFor(hrSlot.slotIcon, hrSlot.slotDesc)
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            transform: Translate { x: 2 }
                                            text: hrSlot.modelData.temp || "--°"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ================= 3. TRANSLUCENT 5-DAY FORECAST CARD WITH DUAL HIGH/LOW TREND LINES =================
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 166
                    radius: 18
                    color: wForecastLg.isLiquidActive ? "transparent" : Qt.rgba(1.0, 1.0, 1.0, 0.09)
                    border.color: Qt.rgba(1.0, 1.0, 1.0, 0.16)
                    border.width: wForecastLg.isLiquidActive ? 0 : 1

                    LiquidGlassSurface {
                        id: wForecastLg
                        anchors.fill: parent
                        z: -1
                        cornerRadius: 18
                        frost: 0.55
                        restTint: Qt.rgba(0.92, 0.96, 1.0, 0.07)
                        restRim: Qt.rgba(1.0, 1.0, 1.0, 0.68)
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 2

                        // Card Header: "Weather forecast"
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            spacing: 6

                            Text {
                                text: "󰃭"
                                font.family: Theme.iconFont
                                font.pixelSize: 11
                                color: Qt.rgba(1, 1, 1, 0.72)
                            }

                            Text {
                                text: "Weather forecast"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.76)
                            }

                            Item { Layout.fillWidth: true }
                        }

                        // 5-Day Top Section: Day Name, Date, Icon (+ Precip %), High Temp
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            spacing: 0

                            Repeater {
                                model: ShellState.weatherForecast

                                delegate: Item {
                                    id: fcCol
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property int popVal: Number(modelData.pop || 0)

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 1

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: fcCol.modelData.day || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: fcCol.index === 0 ? Font.Bold : Font.Medium
                                            color: "#FFFFFF"
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: fcCol.modelData.date || ""
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 9
                                            color: Qt.rgba(1, 1, 1, 0.62)
                                        }

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 28

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: fcCol.popVal >= 30 ? 0 : 4
                                                text: fcCol.modelData.icon || "󰖐"
                                                font.family: Theme.iconFont
                                                font.pixelSize: 15
                                                color: root.iconColorFor(fcCol.modelData.icon, fcCol.modelData.desc)
                                            }

                                            Text {
                                                visible: fcCol.popVal >= 30
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottom: parent.bottom
                                                text: fcCol.popVal + "%"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 8
                                                font.weight: Font.Bold
                                                color: "#7DD3FC"
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            transform: Translate { x: 2 }
                                            text: fcCol.modelData.high || "--°"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                    }
                                }
                            }
                        }

                        // Dual Smooth High/Low Trend Chart (Gold High Line + Sky-Blue Low Line with Dots, Honor style)
                        Canvas {
                            id: trendCanvas
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                const fc = ShellState.weatherForecast;
                                if (!fc || fc.length < 2) return;

                                const n = Math.min(5, fc.length);
                                const colW = width / n;
                                const highs = [];
                                const lows = [];
                                let minT = 999;
                                let maxT = -999;

                                for (let i = 0; i < n; ++i) {
                                    const hi = (fc[i].highNum !== undefined) ? Number(fc[i].highNum) : root.parseNum(fc[i].high, 12);
                                    const lo = (fc[i].lowNum !== undefined) ? Number(fc[i].lowNum) : root.parseNum(fc[i].low, 5);
                                    highs.push(hi);
                                    lows.push(lo);
                                    if (hi > maxT) maxT = hi;
                                    if (lo < minT) minT = lo;
                                }

                                const span = Math.max(4, maxT - minT);
                                const padY = 6;
                                const usableH = Math.max(8, height - padY * 2);

                                const hiPts = [];
                                const loPts = [];
                                for (let i = 0; i < n; ++i) {
                                    const cx = colW * (i + 0.5);
                                    const hy = padY + (1.0 - (highs[i] - minT) / span) * (usableH * 0.55);
                                    const ly = padY + usableH * 0.45 + (1.0 - (lows[i] - minT) / span) * (usableH * 0.55);
                                    hiPts.push({ x: cx, y: hy });
                                    loPts.push({ x: cx, y: ly });
                                }

                                function drawSmoothCurve(pts, strokeStyle) {
                                    ctx.beginPath();
                                    ctx.moveTo(pts[0].x, pts[0].y);
                                    for (let i = 0; i < pts.length - 1; ++i) {
                                        const xc = (pts[i].x + pts[i + 1].x) * 0.5;
                                        const yc = (pts[i].y + pts[i + 1].y) * 0.5;
                                        ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc);
                                    }
                                    ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
                                    ctx.strokeStyle = strokeStyle;
                                    ctx.lineWidth = 2.0;
                                    ctx.stroke();

                                    for (let i = 0; i < pts.length; ++i) {
                                        ctx.beginPath();
                                        ctx.arc(pts[i].x, pts[i].y, 3.0, 0, Math.PI * 2);
                                        ctx.fillStyle = strokeStyle;
                                        ctx.fill();
                                    }
                                }

                                drawSmoothCurve(hiPts, "#F6C445");
                                drawSmoothCurve(loPts, "#5BC0F8");
                            }
                        }

                        // 5-Day Bottom Low Temp Row
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            spacing: 0

                            Repeater {
                                model: ShellState.weatherForecast

                                delegate: Item {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: 2
                                        text: modelData.low || "--°"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: Qt.rgba(1, 1, 1, 0.88)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
