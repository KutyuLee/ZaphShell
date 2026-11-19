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
    readonly property real targetW: ShellState.targetCalendarWidth
    readonly property real targetH: ShellState.calendarHeight
    readonly property real smoothHRatio: Math.min(1.0, Math.max(0.0, (ShellState.smoothRightIslandHeight - Theme.barHeight) / Math.max(1, targetH)))
    readonly property real rightOffset: Theme.barMarginX
    readonly property bool isActiveRight: ShellState.calendarOpen || ShellState.rightIslandOwner === "calendar"

    implicitWidth: targetW + Theme.barMarginX + 56
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calendar"
    WlrLayershell.keyboardFocus: ShellState.calendarOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusiveZone: 0
    visible: h > 0.5 && isActiveRight
    mask: Region { item: calContent }

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth() // 0-11
    property int todayYear: new Date().getFullYear()
    property int todayMonth: new Date().getMonth()
    property int todayDay: new Date().getDate()

    property int activePageIdx: 0
    property var page0Days: computeDays(viewYear, viewMonth)
    property var page1Days: computeDays(viewYear, viewMonth)
    property real page0X: 0
    property real page0Opacity: 1.0
    property real page1X: 0
    property real page1Opacity: 0.0

    property real titleSlideX: 0
    property real titleOpacity: 1.0

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var weekdayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property bool isCurrentMonth: viewYear === todayYear && viewMonth === todayMonth

    function computeDays(y, m) {
        const firstDay = new Date(y, m, 1);
        const startOffset = (firstDay.getDay() + 6) % 7;
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const prevMonthDays = new Date(y, m, 0).getDate();

        const cells = [];
        for (let i = 0; i < 42; ++i) {
            let dayNum = 0;
            let inMonth = false;
            let cellYear = y;
            let cellMonth = m;
            if (i < startOffset) {
                dayNum = prevMonthDays - startOffset + 1 + i;
                cellMonth = m - 1;
                if (cellMonth < 0) { cellMonth = 11; cellYear = y - 1; }
            } else if (i >= startOffset + daysInMonth) {
                dayNum = i - (startOffset + daysInMonth) + 1;
                cellMonth = m + 1;
                if (cellMonth > 11) { cellMonth = 0; cellYear = y + 1; }
            } else {
                dayNum = i - startOffset + 1;
                inMonth = true;
            }
            const isToday = (cellYear === root.todayYear && cellMonth === root.todayMonth && dayNum === root.todayDay);
            const isWeekend = (i % 7) >= 5;
            cells.push({
                day: dayNum,
                inMonth: inMonth,
                isToday: isToday,
                isWeekend: isWeekend
            });
        }
        return cells;
    }

    function switchToMonth(newY, newM, dir, animate) {
        const changed = (newY !== viewYear || newM !== viewMonth);
        viewYear = newY;
        viewMonth = newM;
        const newDays = computeDays(newY, newM);

        if (!animate || !changed) {
            pageSwitchAnim.stop();
            titleAnim.stop();
            if (activePageIdx === 0) {
                page0Days = newDays;
                page0X = 0;
                page0Opacity = 1.0;
                page1X = 0;
                page1Opacity = 0.0;
            } else {
                page1Days = newDays;
                page1X = 0;
                page1Opacity = 1.0;
                page0X = 0;
                page0Opacity = 0.0;
            }
            titleSlideX = 0;
            titleOpacity = 1.0;
            return;
        }

        pageSwitchAnim.stop();
        titleAnim.stop();

        const dist = 46;
        const outIdx = activePageIdx;
        const inIdx = 1 - activePageIdx;
        activePageIdx = inIdx;

        if (inIdx === 0) {
            page0Days = newDays;
            page0X = dir * dist;
            page0Opacity = 0.0;
            outXAnim.target = root;
            outXAnim.property = "page1X";
            outXAnim.to = -dir * dist;
            outOpAnim.target = root;
            outOpAnim.property = "page1Opacity";
            outOpAnim.to = 0.0;
            inXAnim.target = root;
            inXAnim.property = "page0X";
            inXAnim.to = 0;
            inOpAnim.target = root;
            inOpAnim.property = "page0Opacity";
            inOpAnim.to = 1.0;
        } else {
            page1Days = newDays;
            page1X = dir * dist;
            page1Opacity = 0.0;
            outXAnim.target = root;
            outXAnim.property = "page0X";
            outXAnim.to = -dir * dist;
            outOpAnim.target = root;
            outOpAnim.property = "page0Opacity";
            outOpAnim.to = 0.0;
            inXAnim.target = root;
            inXAnim.property = "page1X";
            inXAnim.to = 0;
            inOpAnim.target = root;
            inOpAnim.property = "page1Opacity";
            inOpAnim.to = 1.0;
        }

        titleSlideX = dir * 12;
        titleOpacity = 0.25;
        pageSwitchAnim.restart();
        titleAnim.restart();
    }

    function resetToToday(animate) {
        const now = new Date();
        const ny = now.getFullYear();
        const nm = now.getMonth();
        const dir = (ny > viewYear || (ny === viewYear && nm > viewMonth)) ? 1 : -1;
        todayYear = ny;
        todayMonth = nm;
        todayDay = now.getDate();
        switchToMonth(ny, nm, dir, animate);
    }

    function prevMonth() {
        const nm = viewMonth === 0 ? 11 : viewMonth - 1;
        const ny = viewMonth === 0 ? viewYear - 1 : viewYear;
        switchToMonth(ny, nm, -1, true);
    }

    function nextMonth() {
        const nm = viewMonth === 11 ? 0 : viewMonth + 1;
        const ny = viewMonth === 11 ? viewYear + 1 : viewYear;
        switchToMonth(ny, nm, 1, true);
    }

    ParallelAnimation {
        id: pageSwitchAnim
        NumberAnimation {
            id: outXAnim
            duration: ShellState.animDur(280, 200)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: outOpAnim
            duration: ShellState.animDur(220, 155)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: inXAnim
            duration: ShellState.animDur(300, 215)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: inOpAnim
            duration: ShellState.animDur(260, 185)
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: titleAnim
        NumberAnimation {
            target: root
            property: "titleSlideX"
            to: 0
            duration: ShellState.animDur(240, 175)
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "titleOpacity"
            to: 1.0
            duration: ShellState.animDur(220, 160)
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: ShellState
        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen) {
                root.resetToToday(false);
            }
        }
    }

    HyprlandFocusGrab {
        active: ShellState.calendarOpen && root.visible
        windows: root.barWindow ? [root, root.barWindow] : [root]
        onCleared: {
            ShellState.calendarOpen = false;
        }
    }

    Item {
        focus: ShellState.calendarOpen
        Keys.onEscapePressed: ShellState.calendarOpen = false
    }

    DesktopCaptureSource {
        id: calCap
        targetScreen: root.screen
        sceneWidth: root.screen ? root.screen.width : ShellState.mainScreenWidth
        sceneHeight: root.screen ? root.screen.height : ShellState.mainScreenHeight
        active: ShellState.liquidGlassEnabled && root.visible
    }

    Item {
        id: calContent
        x: root.width - root.rightOffset - ShellState.rightIslandWidth
        y: 0
        width: Math.max(1, ShellState.rightIslandWidth)
        height: Math.max(1, root.h)
        clip: true

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
            id: calScaled
            z: 2
            readonly property bool liquidGlassHost: true
            readonly property var liquidSource: calCap.textureSource
            readonly property bool liquidSourceReady: calCap.ready
            readonly property real liquidOriginX: (root.screen ? root.screen.width : ShellState.mainScreenWidth) - root.width + calContent.x
            readonly property real liquidOriginY: Theme.barBottomY
            width: root.targetW
            height: root.targetH
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: ShellState.calendarOpen ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.InOutQuad } }

            transform: Scale {
                origin.x: root.targetW / 2
                origin.y: 0
                xScale: ShellState.rightIslandWidth / Math.max(1, root.targetW)
                yScale: (0.72 + 0.28 * root.smoothHRatio) * ShellState.rightIslandDeformScaleY
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        clip: true

                        Text {
                            x: root.titleSlideX
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.monthNames[root.viewMonth] + " " + root.viewYear
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                            opacity: root.titleOpacity
                            style: ShellState.liquidGlassEnabled ? Text.Raised : Text.Normal
                            styleColor: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.18 : 0.65)
                        }
                    }

                    Rectangle {
                        id: todayBtn
                        implicitWidth: todayLabel.implicitWidth + 14
                        implicitHeight: 22
                        radius: 11
                        opacity: root.isCurrentMonth ? 0.0 : 1.0
                        visible: opacity > 0.01
                        enabled: !root.isCurrentMonth
                        scale: (root.isCurrentMonth ? 0.86 : 1.0) * (todayMouse.pressed ? 0.91 : (todayMouse.containsMouse ? 1.06 : 1.0))
                        color: todayBtnLg.isLiquidActive
                            ? "transparent"
                            : (todayMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassSurface)
                        border.width: todayBtnLg.isLiquidActive ? 0 : 1
                        border.color: Theme.glassBorder

                        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(220, 150); easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 115); easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 115) } }

                        LiquidGlassSurface {
                            id: todayBtnLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: 11
                            hovered: todayMouse.containsMouse
                        }

                        Text {
                            id: todayLabel
                            anchors.centerIn: parent
                            text: "Today"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.accent
                        }

                        MouseArea {
                            id: todayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetToToday(true)
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        scale: prevMouse.pressed ? 0.90 : (prevMouse.containsMouse ? 1.08 : 1.0)
                        color: prevLg.isLiquidActive ? "transparent" : (prevMouse.containsMouse ? Theme.glassSurfaceHover : "transparent")

                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: ShellState.animDur(150, 105) } }

                        LiquidGlassSurface {
                            id: prevLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: 12
                            onlyWhenHighlighted: true
                            hovered: prevMouse.containsMouse
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            color: Theme.text
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonth()
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        scale: nextMouse.pressed ? 0.90 : (nextMouse.containsMouse ? 1.08 : 1.0)
                        color: nextLg.isLiquidActive ? "transparent" : (nextMouse.containsMouse ? Theme.glassSurfaceHover : "transparent")

                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: ShellState.animDur(150, 105) } }

                        LiquidGlassSurface {
                            id: nextLg
                            anchors.fill: parent
                            z: -1
                            cornerRadius: 12
                            onlyWhenHighlighted: true
                            hovered: nextMouse.containsMouse
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            color: Theme.text
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonth()
                        }
                    }
                }

                // Fixed weekday header row (doesn't slide when switching months)
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4

                    Repeater {
                        model: root.weekdayNames
                        delegate: Item {
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 18

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.textDim
                                style: ShellState.liquidGlassEnabled ? Text.Raised : Text.Normal
                                styleColor: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.16 : 0.60)
                            }
                        }
                    }
                }

                // Dual-page clipped container for simultaneous outgoing + incoming month slide
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    GridLayout {
                        id: gridPage0
                        x: root.page0X
                        y: 0
                        width: parent.width
                        opacity: root.page0Opacity
                        visible: opacity > 0.01
                        enabled: root.activePageIdx === 0
                        columns: 7
                        rowSpacing: 4
                        columnSpacing: 4

                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                required property int index
                                readonly property var cell: root.page0Days[index]
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 9
                                color: {
                                    if (cell.isToday) return Theme.accent;
                                    if (dayLg0.isLiquidActive) return "transparent";
                                    if (dayMouse0.containsMouse && cell.inMonth) return Theme.glassSurfaceHover;
                                    return "transparent";
                                }

                                LiquidGlassSurface {
                                    id: dayLg0
                                    anchors.fill: parent
                                    z: -1
                                    cornerRadius: 9
                                    onlyWhenHighlighted: true
                                    hovered: dayMouse0.containsMouse && cell.inMonth && !cell.isToday
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: String(cell.day)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: cell.isToday ? Font.Bold : Font.Medium
                                    font.features: { "tnum": 1 }
                                    style: (!cell.isToday && ShellState.liquidGlassEnabled) ? Text.Raised : Text.Normal
                                    styleColor: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.18 : 0.72)
                                    color: {
                                        if (cell.isToday) return Theme.lightMode ? "#FFFFFF" : "#0B0F17";
                                        if (!cell.inMonth) return Theme.textDim;
                                        if (cell.isWeekend) return Theme.subtext;
                                        return Theme.text;
                                    }
                                    opacity: cell.inMonth ? 1.0 : 0.42
                                }

                                MouseArea {
                                    id: dayMouse0
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }
                    }

                    GridLayout {
                        id: gridPage1
                        x: root.page1X
                        y: 0
                        width: parent.width
                        opacity: root.page1Opacity
                        visible: opacity > 0.01
                        enabled: root.activePageIdx === 1
                        columns: 7
                        rowSpacing: 4
                        columnSpacing: 4

                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                required property int index
                                readonly property var cell: root.page1Days[index]
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 9
                                color: {
                                    if (cell.isToday) return Theme.accent;
                                    if (dayLg1.isLiquidActive) return "transparent";
                                    if (dayMouse1.containsMouse && cell.inMonth) return Theme.glassSurfaceHover;
                                    return "transparent";
                                }

                                LiquidGlassSurface {
                                    id: dayLg1
                                    anchors.fill: parent
                                    z: -1
                                    cornerRadius: 9
                                    onlyWhenHighlighted: true
                                    hovered: dayMouse1.containsMouse && cell.inMonth && !cell.isToday
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: String(cell.day)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: cell.isToday ? Font.Bold : Font.Medium
                                    font.features: { "tnum": 1 }
                                    style: (!cell.isToday && ShellState.liquidGlassEnabled) ? Text.Raised : Text.Normal
                                    styleColor: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.18 : 0.72)
                                    color: {
                                        if (cell.isToday) return Theme.lightMode ? "#FFFFFF" : "#0B0F17";
                                        if (!cell.inMonth) return Theme.textDim;
                                        if (cell.isWeekend) return Theme.subtext;
                                        return Theme.text;
                                    }
                                    opacity: cell.inMonth ? 1.0 : 0.42
                                }

                                MouseArea {
                                    id: dayMouse1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
