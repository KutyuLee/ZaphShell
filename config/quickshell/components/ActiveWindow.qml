import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Item {
    id: root

    property var targetScreen: null
    property bool ownsActivePanel: true
    implicitHeight: 26
    implicitWidth: Math.min(contentRow.implicitWidth + 8, 420)
    visible: opacity > 0.01

    readonly property var activeTop: {
        if (root.targetScreen) {
            return ShellState.topWindowForScreen(root.targetScreen);
        }
        return Hyprland.activeToplevel;
    }

    function getAppInfo() {
        const top = root.activeTop;
        if (!top) {
            return {
                name: "Desktop",
                icon: "",
                glyph: "󰍹"
            };
        }

        let rawClass = "";
        if (top.wayland && top.wayland.appId) {
            rawClass = top.wayland.appId;
        } else if (top.lastIpcObject && top.lastIpcObject["class"]) {
            rawClass = top.lastIpcObject["class"];
        } else if (top.lastIpcObject && top.lastIpcObject["initialClass"]) {
            rawClass = top.lastIpcObject["initialClass"];
        }

        let appName = "";
        let appIcon = "";

        if (rawClass) {
            const entry = DesktopEntries.heuristicLookup(rawClass);
            if (entry) {
                if (entry.name) appName = entry.name;
                if (entry.icon) appIcon = entry.icon;
            }
            if (!appName) {
                const parts = rawClass.split(".");
                const last = parts[parts.length - 1];
                appName = last.length > 0 ? (last.charAt(0).toUpperCase() + last.slice(1)) : rawClass;
            }
            if (!appIcon) {
                appIcon = rawClass.toLowerCase();
            }
        }

        if (!appName && top.title) {
            const dashParts = top.title.split(" — ");
            if (dashParts.length > 1) {
                appName = dashParts[dashParts.length - 1];
            } else {
                const hyphenParts = top.title.split(" - ");
                if (hyphenParts.length > 1) {
                    appName = hyphenParts[hyphenParts.length - 1];
                } else {
                    appName = top.title;
                }
            }
        }

        return {
            name: appName || "Desktop",
            icon: appIcon || "application-x-executable",
            glyph: "󰵆"
        };
    }

    readonly property var liveAppInfo: getAppInfo()
    property var appInfo: ({ name: "Desktop", icon: "", glyph: "󰍹" })

    function syncAppInfo() {
        if (!root.ownsActivePanel || ShellState.centerIslandMode === "collapsed") {
            appInfo = liveAppInfo;
        }
    }

    onLiveAppInfoChanged: syncAppInfo()
    Component.onCompleted: appInfo = liveAppInfo

    Connections {
        target: ShellState
        function onCenterIslandModeChanged() {
            if (!root.ownsActivePanel || ShellState.centerIslandMode === "collapsed") {
                root.appInfo = root.liveAppInfo;
            }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 8
        opacity: ShellState.showWindowTitle ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: ShellState.animDur(240, 160); easing.type: ShellState.animPrimaryEase } }
        layer.enabled: ShellState.liquidGlassEnabled
        layer.effect: DropShadow {
            verticalOffset: 1
            radius: 4
            samples: 9
            color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
        }

        // App Icon
        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            IconImage {
                id: appIcon
                anchors.centerIn: parent
                width: 18
                height: 18
                source: root.appInfo.icon ? Quickshell.iconPath(root.appInfo.icon) : ""
            }

            Text {
                anchors.centerIn: parent
                visible: appIcon.status !== Image.Ready
                text: root.appInfo.glyph || "󰵆"
                font.family: Theme.iconFont
                font.pixelSize: 15
                color: Theme.subtext
            }
        }

        // App Name
        Text {
            id: appText
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 380
            elide: Text.ElideRight
            text: root.appInfo.name
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeNormal
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }
}
