import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import ".."

IslandFloatPanel {
    id: root

    open: ShellState.clipboardOpen
    modalMode: "clipboard"
    layerNamespace: "quickshell-clipboard"
    subLayoutRev: clipList.contentY
    onCloseRequested: ShellState.clipboardOpen = false

    property var allClips: []
    property var filteredClips: []
    property var clipsByKey: ({})
    property int selectedIndex: 0

    function applyFilteredClips(result) {
        const nextMap = {};
        const nextKeys = [];
        const seen = {};
        for (let i = 0; i < result.length; ++i) {
            const c = result[i];
            let k = String(c.id || c.raw || ("clip_" + i));
            if (seen[k]) k = k + "#" + i;
            seen[k] = true;
            nextKeys.push(k);
            nextMap[k] = c;
        }
        root.clipsByKey = nextMap;
        root.filteredClips = result;
        ShellState.syncKeyedListModel(filteredClipsModel, nextKeys);
    }

    function refreshClips() {
        clipProc.running = true;
    }

    Process {
        id: clipProc
        command: [ShellState.script("clipboard.sh"), "list"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        root.allClips = parsed;
                        root.filterClips();
                    }
                } catch (e) {}
            }
        }
    }

    function filterClips() {
        const query = searchInput.text.trim().toLowerCase();
        const next = (query.length === 0)
            ? root.allClips
            : root.allClips.filter(c => {
                return (c.text && c.text.toLowerCase().includes(query)) ||
                       (c.preview && c.preview.toLowerCase().includes(query));
            });
        applyFilteredClips(next);
        root.selectedIndex = 0;
        clipList.scrollTargetY = 0;
        clipList.contentY = 0;
    }

    function copyAndPaste(clip) {
        if (!clip) return;
        Quickshell.execDetached([ShellState.script("clipboard.sh"), "paste", clip.raw]);
        ShellState.clipboardOpen = false;
    }

    function deleteClip(clip, index) {
        if (!clip) return;
        Quickshell.execDetached([ShellState.script("clipboard.sh"), "delete", clip.raw]);
        const updated = root.allClips.filter(c => c.id !== clip.id);
        root.allClips = updated;
        root.filterClips();
    }

    function clearAllClips() {
        Quickshell.execDetached([ShellState.script("clipboard.sh"), "wipe"]);
        root.allClips = [];
        applyFilteredClips([]);
        root.selectedIndex = 0;
    }

    Connections {
        target: ShellState
        function onClipboardOpenChanged() {
            if (ShellState.clipboardOpen) {
                searchInput.text = "";
                root.refreshClips();
                searchInput.forceActiveFocus();
                focusTimer.restart();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 45
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

            // Header Row: Title, Count badge, Clear button
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰅍"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.subtext
                }

                Text {
                    text: "Clipboard History"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.text
                }

                // Count Pill
                Rectangle {
                    implicitWidth: countText.implicitWidth + 12
                    implicitHeight: 20
                    radius: 10
                    color: clipCountLg.isLiquidActive ? "transparent" : Theme.glassCard
                    border.width: clipCountLg.isLiquidActive ? 0 : 1
                    border.color: Theme.glassBorder

                    LiquidGlassSurface {
                        id: clipCountLg
                        anchors.fill: parent
                        z: -1
                        cornerRadius: 10
                    }

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: root.filteredClips.length + " clips"
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.subtext
                    }
                }

                Item { Layout.fillWidth: true }

                // Clear History Button
                Rectangle {
                    visible: root.allClips.length > 0
                    implicitWidth: clearRow.implicitWidth + 14
                    implicitHeight: 24
                    radius: 12
                    color: clipClearLg.isLiquidActive ? "transparent" : (clearMouse.containsMouse ? Theme.glassSurfaceHover : Theme.glassCard)
                    border.width: clipClearLg.isLiquidActive ? 0 : 1
                    border.color: Theme.glassBorder
                    scale: clearMouse.pressed ? 0.94 : (clearMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 105); easing.type: ShellState.animPrimaryEase } }
                    Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 115) } }

                    LiquidGlassSurface {
                        id: clipClearLg
                        anchors.fill: parent
                        z: -1
                        cornerRadius: 12
                        hovered: clearMouse.containsMouse
                    }

                    RowLayout {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: "󰆴"
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                            color: Theme.red
                        }
                        Text {
                            text: "Clear All"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.subtext
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAllClips()
                    }
                }

                // Close Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: closeMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                    scale: closeMouse.pressed ? 0.88 : (closeMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                    Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                        color: closeMouse.containsMouse ? Theme.text : Theme.subtext
                        Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.clipboardOpen = false
                    }
                }
            }

            // Clipboard Items List
            ListView {
                id: clipList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                topMargin: 4
                bottomMargin: 8
                model: ListModel { id: filteredClipsModel }
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

                // Balanced, accumulating mouse wheel & touchpad scrolling (same speed as AppLauncher)
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const maxContentY = Math.max(0, clipList.contentHeight - clipList.height);
                        const delta = event.angleDelta.y;
                        const step = (delta !== 0 ? (delta / 120.0) : (event.pixelDelta.y / 18.0)) * 115;
                        clipList.scrollTargetY = Math.max(0, Math.min(maxContentY, clipList.scrollTargetY - step));
                        clipList.contentY = clipList.scrollTargetY;
                        event.accepted = true;
                    }
                }

                // Multi-stop perceptual ease-out alpha OpacityMask (soft blur/fade at top and bottom, same as AppLauncher)
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: Math.max(1, clipList.width)
                        height: Math.max(1, clipList.height)

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1.0 - clipList.topFade) }
                                GradientStop { position: 0.018; color: Qt.rgba(1, 1, 1, 1.0 - clipList.topFade) }
                                GradientStop { position: 0.045; color: Qt.rgba(1, 1, 1, 1.0 - 0.72 * clipList.topFade) }
                                GradientStop { position: 0.08; color: Qt.rgba(1, 1, 1, 1.0 - 0.32 * clipList.topFade) }
                                GradientStop { position: 0.12; color: "#ffffffff" }
                                GradientStop { position: 0.86; color: "#ffffffff" }
                                GradientStop { position: 0.90; color: Qt.rgba(1, 1, 1, 1.0 - 0.32 * clipList.botFade) }
                                GradientStop { position: 0.945; color: Qt.rgba(1, 1, 1, 1.0 - 0.75 * clipList.botFade) }
                                GradientStop { position: 0.982; color: Qt.rgba(1, 1, 1, 1.0 - clipList.botFade) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1.0 - clipList.botFade) }
                            }
                        }
                    }
                }

                delegate: Rectangle {
                    id: clipCard
                    required property int index
                    required property string itemKey
                    readonly property var clipData: root.clipsByKey[itemKey] || ({ id: "", raw: "", text: "", preview: "", isImage: false })

                    readonly property bool isSelected: root.selectedIndex === clipCard.index
                    readonly property bool isHovered: cardMouse.containsMouse || clipCard.isSelected

                    width: clipList.width
                    implicitHeight: 46
                    radius: 12
                    color: clipCardLg.isLiquidActive ? "transparent" : (clipCard.isHovered ? Theme.glassSurfaceHover : (clipCard.isSelected ? Theme.glassSurfaceActive : Theme.glassCard))
                    border.width: clipCardLg.isLiquidActive ? 0 : 1
                    border.color: clipCard.isSelected ? Theme.glassHighlight : (clipCard.isHovered ? Theme.glassCardBorder : Theme.glassBorder)
                    onYChanged: {
                        clipCardLg.syncScreenBounds();
                        clipTypeLg.syncScreenBounds();
                        clipDelLg.syncScreenBounds();
                    }

                    LiquidGlassSurface {
                        id: clipCardLg
                        anchors.fill: parent
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        z: -1
                        cornerRadius: 12
                        active: clipCard.isSelected
                        hovered: clipCard.isHovered
                    }

                    property real pressScale: cardMouse.pressed ? 0.98 : 1.0
                    Behavior on pressScale { NumberAnimation { duration: 110; easing.type: ShellState.animPrimaryEase } }
                    transform: Scale {
                        origin.x: clipCard.width / 2
                        origin.y: clipCard.height / 2
                        xScale: clipCard.pressScale
                        yScale: clipCard.pressScale
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        // Type Icon (Text vs Image)
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: clipTypeLg.isLiquidActive ? "transparent" : Theme.glassSurface

                            LiquidGlassSurface {
                                id: clipTypeLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 14
                            }

                            Text {
                                anchors.centerIn: parent
                                text: clipCard.clipData.isImage ? "󰋩" : "󰦨"
                                font.family: Theme.iconFont
                                font.pixelSize: 14
                                color: clipCard.clipData.isImage ? "#ecc94b" : Theme.subtext
                            }
                        }

                        // Text Preview
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            layer.enabled: ShellState.liquidGlassEnabled && !Theme.lightMode
                            layer.effect: DropShadow {
                                verticalOffset: 1
                                radius: 4
                                samples: 9
                                color: Qt.rgba(0, 0, 0, 0.72)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: clipCard.clipData.preview || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: Theme.text
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                text: clipCard.clipData.isImage ? "Image in clipboard" : ("#" + (clipCard.index + 1))
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textDim
                            }
                        }

                        // Delete Individual Item
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: clipDelLg.isLiquidActive ? "transparent" : (delMouse.containsMouse ? Theme.glassSurfaceHover : "transparent")
                            opacity: clipCard.isHovered ? 1.0 : 0.0
                            scale: delMouse.pressed ? 0.88 : (delMouse.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            LiquidGlassSurface {
                                id: clipDelLg
                                anchors.fill: parent
                                z: -1
                                cornerRadius: 13
                                hovered: delMouse.containsMouse
                                onlyWhenHighlighted: true
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "󰆴"
                                font.family: Theme.iconFont
                                font.pixelSize: 12
                                color: delMouse.containsMouse ? Theme.red : Theme.subtext
                                Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                            }

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteClip(clipCard.clipData, clipCard.index)
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = clipCard.index
                        onClicked: root.copyAndPaste(clipCard.clipData)
                    }
                }

                // Empty State
                Text {
                    anchors.centerIn: parent
                    visible: root.filteredClips.length === 0
                    text: searchInput.text.length > 0 ? "No matching clips found" : "Clipboard history is empty"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.textDim
                }
            }

            // Search Bar at Bottom (matching AppLauncher pill radius)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusPill
                color: clipSearchLg.isLiquidActive ? "transparent" : Theme.glassCard
                border.width: clipSearchLg.isLiquidActive ? 0 : 1
                border.color: searchInput.activeFocus ? Theme.glassHighlight : Theme.glassBorder

                LiquidGlassSurface {
                    id: clipSearchLg
                    anchors.fill: parent
                    z: -1
                    cornerRadius: 22
                    active: searchInput.activeFocus
                }

                Behavior on border.color { ColorAnimation { duration: 140 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.family: Theme.iconFont
                        font.pixelSize: 16
                        color: searchInput.activeFocus ? Theme.text : Theme.textDim
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: "#ffffff"
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Type to search clips... (Enter to paste, Del to remove)"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDim
                        }

                        onTextChanged: root.filterClips()

                        onAccepted: {
                            if (root.filteredClips.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredClips.length) {
                                root.copyAndPaste(root.filteredClips[root.selectedIndex]);
                            }
                        }

                        Keys.onDownPressed: event => {
                            if (root.filteredClips.length > 0) {
                                root.selectedIndex = Math.min(root.filteredClips.length - 1, root.selectedIndex + 1);
                                clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                clipList.scrollTargetY = clipList.contentY;
                                event.accepted = true;
                            }
                        }

                        Keys.onUpPressed: event => {
                            if (root.filteredClips.length > 0) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                                clipList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                clipList.scrollTargetY = clipList.contentY;
                                event.accepted = true;
                            }
                        }

                        Keys.onReturnPressed: event => {
                            if (root.filteredClips.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredClips.length) {
                                root.copyAndPaste(root.filteredClips[root.selectedIndex]);
                                event.accepted = true;
                            }
                        }

                        Keys.onEnterPressed: event => {
                            if (root.filteredClips.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredClips.length) {
                                root.copyAndPaste(root.filteredClips[root.selectedIndex]);
                                event.accepted = true;
                            }
                        }

                        Keys.onDeletePressed: event => {
                            if (root.filteredClips.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.filteredClips.length) {
                                root.deleteClip(root.filteredClips[root.selectedIndex], root.selectedIndex);
                                event.accepted = true;
                            }
                        }

                        Keys.onEscapePressed: event => {
                            ShellState.clipboardOpen = false;
                            event.accepted = true;
                        }
                    }

                    // Clear Text Button
                    Rectangle {
                        visible: searchInput.text.length > 0
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: clearSearchMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                        scale: clearSearchMouse.pressed ? 0.88 : (clearSearchMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(150, 100); easing.type: ShellState.animPrimaryEase } }
                        Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                            color: clearSearchMouse.containsMouse ? Theme.text : Theme.subtext
                            Behavior on color { ColorAnimation { duration: ShellState.animDur(160, 110) } }
                        }

                        MouseArea {
                            id: clearSearchMouse
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
}
