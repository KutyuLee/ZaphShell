import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import ".."

IslandFloatPanel {
    id: root

    open: ShellState.launcherOpen
    modalMode: "launcher"
    layerNamespace: "quickshell-launcher"
    subLayoutRev: appList.contentY
    onCloseRequested: ShellState.launcherOpen = false

    Timer {
        id: focusTimer
        interval: 45
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

            // ================= APP LIST (TOP, LIKE CAELESTIA) =================
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                topMargin: 6
                bottomMargin: 16
                model: ListModel { id: filteredAppsModel }
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: ShellState.animDur(220, 140); easing.type: ShellState.animPrimaryEase }
                        NumberAnimation { property: "scale"; from: 0.94; to: 1.0; duration: ShellState.animDur(240, 150); easing.type: ShellState.animPrimaryEase }
                    }
                }
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0.0; duration: ShellState.animDur(180, 115); easing.type: ShellState.animPrimaryEase }
                        NumberAnimation { property: "scale"; to: 0.94; duration: ShellState.animDur(180, 115); easing.type: ShellState.animPrimaryEase }
                    }
                }
                move: Transition {
                    NumberAnimation { property: "y"; duration: ShellState.animDur(240, 150); easing.type: ShellState.animPrimaryEase }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: ShellState.animDur(240, 150); easing.type: ShellState.animPrimaryEase }
                }

                property real scrollTargetY: 0
                readonly property real topFade: Math.min(1.0, Math.max(0.0, contentY / 14.0))
                readonly property real botFade: Math.min(1.0, Math.max(0.0, (contentHeight - height - contentY) / 14.0))

                Behavior on contentY {
                    NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                }

                // Balanced, accumulating mouse wheel & touchpad scrolling
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const maxContentY = Math.max(0, appList.contentHeight - appList.height);
                        const delta = event.angleDelta.y;
                        const step = (delta !== 0 ? (delta / 120.0) : (event.pixelDelta.y / 18.0)) * 115;
                        appList.scrollTargetY = Math.max(0, Math.min(maxContentY, appList.scrollTargetY - step));
                        appList.contentY = appList.scrollTargetY;
                        event.accepted = true;
                    }
                }

                // Multi-stop perceptual ease-out alpha OpacityMask (reaches 0 alpha inside clip bounds so no hard cut ever appears)
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: Math.max(1, appList.width)
                        height: Math.max(1, appList.height)

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0 - appList.topFade) }
                                GradientStop { position: 0.018; color: Qt.rgba(1, 1, 1, 1.0 - appList.topFade) }
                                GradientStop { position: 0.045; color: Qt.rgba(1, 1, 1, 1.0 - 0.72 * appList.topFade) }
                                GradientStop { position: 0.08; color: Qt.rgba(1, 1, 1, 1.0 - 0.32 * appList.topFade) }
                                GradientStop { position: 0.12; color: "#ffffffff" }
                                GradientStop { position: 0.86; color: "#ffffffff" }
                                GradientStop { position: 0.90; color: Qt.rgba(1, 1, 1, 1.0 - 0.32 * appList.botFade) }
                                GradientStop { position: 0.945; color: Qt.rgba(1, 1, 1, 1.0 - 0.75 * appList.botFade) }
                                GradientStop { position: 0.982; color: Qt.rgba(1, 1, 1, 1.0 - appList.botFade) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.0 - appList.botFade) }
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: delegateRoot
                    required property string itemKey
                    required property int index
                    readonly property var app: root.appsByKey[itemKey] || ({ name: "", comment: "", genericName: "", icon: "", isAction: false })
                    readonly property bool isSelected: appList.currentIndex === index || itemArea.containsMouse

                    width: appList.width - 8
                    height: 54
                    radius: 12
                    color: appRowLg.isLiquidActive ? "transparent" : (isSelected ? Theme.glassSurfaceActive : "transparent")
                    border.color: appRowLg.isLiquidActive ? "transparent" : (isSelected ? Theme.glassHighlight : "transparent")
                    border.width: appRowLg.isLiquidActive ? 0 : 1
                    onYChanged: appRowLg.syncScreenBounds()

                    LiquidGlassSurface {
                        id: appRowLg
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        z: -1
                        cornerRadius: 12
                        onlyWhenHighlighted: true
                        active: delegateRoot.isSelected
                    }

                    property real pressScale: itemArea.pressed ? 0.98 : 1.0
                    Behavior on pressScale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: ShellState.animPrimaryEase } }
                    transform: Scale {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
                        xScale: delegateRoot.pressScale
                        yScale: delegateRoot.pressScale
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        // App Icon
                        Item {
                            width: 34
                            height: 34

                            IconImage {
                                id: appImg
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                visible: !delegateRoot.app.isAction
                                source: delegateRoot.app.isAction ? "" : Quickshell.iconPath(delegateRoot.app.icon)
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: delegateRoot.app.isAction || appImg.status !== Image.Ready
                                text: delegateRoot.app.actionIcon || "󰵆"
                                font.family: Theme.iconFont
                                font.pixelSize: 20
                                color: Theme.subtext
                            }
                        }

                        // App Title & Subtitle
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            layer.enabled: ShellState.liquidGlassEnabled && !Theme.lightMode
                            layer.effect: DropShadow {
                                verticalOffset: 1
                                radius: 4
                                samples: 9
                                color: Qt.rgba(0, 0, 0, 0.72)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: delegateRoot.app.name || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeNormal
                                font.weight: Font.DemiBold
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: delegateRoot.app.comment || delegateRoot.app.genericName || "Application"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.subtext
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.launchApp(delegateRoot.app);
                        }
                    }
                }
            }

            // ================= SEARCH PILL (BOTTOM, LIKE CAELESTIA) =================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusPill
                color: appSearchLg.isLiquidActive ? "transparent" : Theme.glassCard
                border.color: searchInput.activeFocus ? Theme.glassHighlight : Theme.glassBorder
                border.width: appSearchLg.isLiquidActive ? 0 : 1

                LiquidGlassSurface {
                    id: appSearchLg
                    anchors.fill: parent
                    z: -1
                    cornerRadius: 22
                    active: searchInput.activeFocus
                }

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.family: Theme.iconFont
                        font.pixelSize: 15
                        color: searchInput.activeFocus ? Theme.text : Theme.textDim
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeNormal
                        color: Theme.text
                        selectionColor: Theme.blueContainer
                        selectedTextColor: Theme.blueOnContainer
                        clip: true

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Search apps, \"> cmd\", or \"= math\"..."
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeNormal
                            color: Theme.textDim
                        }

                        onTextChanged: {
                            root.updateFilteredList();
                        }

                        Keys.onEscapePressed: {
                            ShellState.closeAll();
                        }

                        Keys.onDownPressed: {
                            if (appList.count > 0) {
                                appList.currentIndex = (appList.currentIndex + 1) % appList.count;
                            }
                        }

                        Keys.onUpPressed: {
                            if (appList.count > 0) {
                                appList.currentIndex = (appList.currentIndex - 1 + appList.count) % appList.count;
                            }
                        }

                        Keys.onReturnPressed: {
                            if (root.filteredApps.length > 0) {
                                root.launchApp(root.filteredApps[0]);
                            }
                        }

                        Keys.onEnterPressed: {
                            if (root.filteredApps.length > 0) {
                                root.launchApp(root.filteredApps[0]);
                            }
                        }
                    }

                    // Clear button
                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 11
                        visible: searchInput.text.length > 0
                        color: clearArea.containsMouse ? Theme.glassSurfaceHover : "transparent"
                        scale: clearArea.pressed ? 0.88 : (clearArea.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                        Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            color: clearArea.containsMouse ? Theme.text : Theme.textDim
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

    property var filteredApps: []
    property var appsByKey: ({})
    property var appLaunchCounts: ({})

    function applyFilteredApps(result) {
        const nextMap = {};
        const nextKeys = [];
        const seen = {};
        for (let i = 0; i < result.length; ++i) {
            const item = result[i];
            let k = item.isAction
                ? ("__action:" + item.actionType + ":" + item.payload)
                : String(item.id || item.name || ("app_" + i));
            if (seen[k]) k = k + "#" + i;
            seen[k] = true;
            nextKeys.push(k);
            nextMap[k] = item;
        }
        root.appsByKey = nextMap;
        root.filteredApps = result;
        ShellState.syncKeyedListModel(filteredAppsModel, nextKeys);
    }

    function evalMathExpr(expr) {
        if (!expr || expr.length > 80) return null;
        // Allow only digits, whitespace, operators, parentheses, decimal point, and known math identifiers
        const cleaned = expr.replace(/\^/g, "**").trim();
        if (!/^[0-9+\-*/%().\s,a-zA-Z]+$/.test(cleaned)) return null;
        const stripped = cleaned.replace(/\b(pi|e|sqrt|sin|cos|tan|log|abs|round|floor|ceil|pow|min|max)\b/gi, "");
        if (/[a-zA-Z_]/.test(stripped)) return null;
        try {
            const fn = new Function(
                "pi", "e", "sqrt", "sin", "cos", "tan", "log", "abs", "round", "floor", "ceil", "pow", "min", "max",
                "return (" + cleaned + ");"
            );
            const val = fn(Math.PI, Math.E, Math.sqrt, Math.sin, Math.cos, Math.tan, Math.log, Math.abs, Math.round, Math.floor, Math.ceil, Math.pow, Math.min, Math.max);
            if (typeof val === "number" && isFinite(val)) {
                return Number.isInteger(val) ? String(val) : String(Number(val.toFixed(8)));
            }
        } catch (err) {}
        return null;
    }

    function updateFilteredList() {
        const raw = searchInput.text;
        const trimmed = raw.trim();
        const query = trimmed.toLowerCase();
        const result = [];

        // Calculator mode: "= <expr>"
        if (trimmed.startsWith("=")) {
            const expr = trimmed.slice(1).trim();
            const ans = evalMathExpr(expr);
            if (ans !== null) {
                result.push({
                    isAction: true,
                    actionType: "calc",
                    actionIcon: "󰃬",
                    name: "= " + ans,
                    comment: "Press Enter to copy result to clipboard",
                    payload: ans
                });
            }
            applyFilteredApps(result);
            appList.scrollTargetY = 0;
            appList.contentY = 0;
            appList.currentIndex = 0;
            return;
        }

        // Command runner mode: "> <cmd>"
        if (trimmed.startsWith(">")) {
            const cmd = trimmed.slice(1).trim();
            if (cmd.length > 0) {
                result.push({
                    isAction: true,
                    actionType: "cmd",
                    actionIcon: "󰆍",
                    name: "Run: " + cmd,
                    comment: "Execute shell command",
                    payload: cmd
                });
            }
            applyFilteredApps(result);
            appList.scrollTargetY = 0;
            appList.contentY = 0;
            appList.currentIndex = 0;
            return;
        }

        if (!DesktopEntries.applications || !DesktopEntries.applications.values) {
            applyFilteredApps([]);
            return;
        }

        const all = DesktopEntries.applications.values;
        for (let i = 0; i < all.length; ++i) {
            const entry = all[i];
            if (!entry || entry.noDisplay || !entry.name) continue;

            if (query === "") {
                result.push(entry);
            } else {
                const nameMatch = entry.name.toLowerCase().includes(query);
                const commentMatch = entry.comment && entry.comment.toLowerCase().includes(query);
                const genericMatch = entry.genericName && entry.genericName.toLowerCase().includes(query);
                if (nameMatch || commentMatch || genericMatch) {
                    result.push(entry);
                }
            }
        }

        const counts = root.appLaunchCounts;
        result.sort((a, b) => {
            if (query.length > 0) {
                const aStarts = a.name.toLowerCase().startsWith(query) ? 1 : 0;
                const bStarts = b.name.toLowerCase().startsWith(query) ? 1 : 0;
                if (aStarts !== bStarts) return bStarts - aStarts;
            }
            const ca = counts[a.id || a.name] || 0;
            const cb = counts[b.id || b.name] || 0;
            if (ca !== cb) return cb - ca;
            return a.name.localeCompare(b.name);
        });

        applyFilteredApps(result);
        appList.scrollTargetY = 0;
        appList.contentY = 0;
        appList.currentIndex = 0;
    }

    function launchApp(app) {
        if (!app) return;
        if (app.isAction) {
            if (app.actionType === "calc") {
                Quickshell.execDetached(["wl-copy", app.payload]);
            } else if (app.actionType === "cmd") {
                Quickshell.execDetached(["bash", "-lc", app.payload]);
            }
            ShellState.closeAll();
            return;
        }
        const key = app.id || app.name;
        if (key) {
            const next = Object.assign({}, root.appLaunchCounts);
            next[key] = (next[key] || 0) + 1;
            root.appLaunchCounts = next;
        }
        if (app.execute) {
            app.execute();
        }
        ShellState.closeAll();
    }

    Connections {
        target: ShellState
        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                searchInput.text = "";
                root.updateFilteredList();
                searchInput.forceActiveFocus();
                focusTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        updateFilteredList();
    }
}
