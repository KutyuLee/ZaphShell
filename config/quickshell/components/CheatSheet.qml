import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

IslandFloatPanel {
    id: root

    open: ShellState.cheatSheetOpen
    modalMode: "cheatSheet"
    layerNamespace: "quickshell-cheatsheet"
    onCloseRequested: ShellState.cheatSheetOpen = false

    // Dedicated matte-frosted readability backing matching Settings
    Rectangle {
        anchors.fill: parent
        z: -2
        radius: 22
        color: Theme.lightMode ? Qt.rgba(0.95, 0.96, 0.98, 0.44) : Qt.rgba(0.04, 0.05, 0.08, 0.46)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 42
                        Layout.preferredHeight: 42
                        radius: 21
                        color: Theme.glassSurfaceHover
                        border.color: Theme.glassBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "󰌌"
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                            color: Theme.text
                        }
                    }

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: "Keyboard Shortcuts"
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.text
                        }

                        Text {
                            text: "System & desktop keybindings"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.subtext
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Top-Right Esc Close Pill
                    Rectangle {
                        implicitWidth: 68
                        implicitHeight: 32
                        radius: 16
                        color: closeEscMouse.containsMouse
                            ? (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.08) : Qt.rgba(1.0, 1.0, 1.0, 0.12))
                            : (Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.045) : Qt.rgba(1.0, 1.0, 1.0, 0.07))
                        border.color: closeEscMouse.containsMouse ? Theme.glassHighlight : Theme.glassCardBorder
                        border.width: 1
                        scale: closeEscMouse.pressed ? 0.93 : (closeEscMouse.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase } }
                        Behavior on color { ColorAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "Esc"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.text
                            }

                            Text {
                                text: "✕"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.subtext
                            }
                        }

                        MouseArea {
                            id: closeEscMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                ShellState.cheatSheetOpen = false;
                            }
                        }
                    }
                }

                // Separator line
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.glassBorder
                }

                // Full Non-Scrollable Grid of 9 Categorized Shortcut Cards
                GridLayout {
                    id: shortcutsGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    rowSpacing: 10
                    columnSpacing: 12

                        // 1. Applications
                        ShortcutCard {
                            icon: "󰅟"
                            title: "Applications"
                            ShortcutRow { key: "SUPER + T"; desc: "Terminal (kitty)" }
                            ShortcutRow { key: "SUPER + W"; desc: "Browser (firefox)" }
                            ShortcutRow { key: "SUPER + C"; desc: "Editor (codium)" }
                            ShortcutRow { key: "SUPER + E"; desc: "File Explorer (thunar)" }
                            ShortcutRow { key: "CTRL + ALT + V"; desc: "Audio (pwvucontrol)" }
                        }

                        // 2. Special Workspaces (Scratchpads)
                        ShortcutCard {
                            icon: "󰵉"
                            title: "Scratchpads"
                            ShortcutRow { key: "SUPER + S"; desc: "Toggle Special" }
                            ShortcutRow { key: "CTRL+SHIFT+Esc"; desc: "System Monitor" }
                            ShortcutRow { key: "SUPER + M"; desc: "Music Scratchpad" }
                            ShortcutRow { key: "SUPER + D"; desc: "Communication" }
                            ShortcutRow { key: "SUPER+ALT+S"; desc: "Move Window to Special" }
                        }

                        // 3. System & Interface
                        ShortcutCard {
                            icon: "󰍹"
                            title: "System & Interface"
                            ShortcutRow { key: "SUPER (Tap)"; desc: "App Launcher" }
                            ShortcutRow { key: "SUPER + Space"; desc: "Switch Keyboard Layout" }
                            ShortcutRow { key: "SUPER + A"; desc: "Show / Hide Desktop" }
                            ShortcutRow { key: "CTRL+ALT+Del"; desc: "Power / Session Menu" }
                            ShortcutRow { key: "SUPER + N"; desc: "Toggle Control Center" }
                            ShortcutRow { key: "SUPER + L"; desc: "Lock Screen" }
                            ShortcutRow { key: "SUPER+SHIFT+L"; desc: "Suspend / Sleep" }
                            ShortcutRow { key: "SUPER+SHIFT+R"; desc: "Restart Shell" }
                        }

                        // 4. Window Actions & Sizing
                        ShortcutCard {
                            icon: "󰖲"
                            title: "Window Actions"
                            ShortcutRow { key: "SUPER + Q"; desc: "Close Window" }
                            ShortcutRow { key: "SUPER+ALT+Space"; desc: "Toggle Floating" }
                            ShortcutRow { key: "SUPER + F"; desc: "Fullscreen" }
                            ShortcutRow { key: "SUPER + ALT + F"; desc: "Bordered Fullscreen" }
                            ShortcutRow { key: "SUPER + ALT + \\"; desc: "Picture-in-Picture" }
                        }

                        // 5. Window Sizing & Positioning
                        ShortcutCard {
                            icon: "󰩨"
                            title: "Sizing & Modes"
                            ShortcutRow { key: "SUPER + P"; desc: "Pin Window" }
                            ShortcutRow { key: "SUPER + Z / X"; desc: "Move / Resize Mode" }
                            ShortcutRow { key: "CTRL+SUPER+\\"; desc: "Center Window" }
                            ShortcutRow { key: "SUPER + - / ="; desc: "Adjust Window Width" }
                            ShortcutRow { key: "SUPER+SHIFT+-/="; desc: "Adjust Window Height" }
                        }

                        // 6. Window Groups / Tabbing
                        ShortcutCard {
                            icon: "󰓩"
                            title: "Window Groups"
                            ShortcutRow { key: "ALT + TAB"; desc: "Cycle Next Window" }
                            ShortcutRow { key: "SHIFT+ALT+TAB"; desc: "Cycle Prev Window" }
                            ShortcutRow { key: "CTRL+ALT+TAB"; desc: "Cycle Group Window" }
                            ShortcutRow { key: "SUPER + ,"; desc: "Toggle Window Group" }
                            ShortcutRow { key: "SUPER + U"; desc: "Ungroup Window" }
                        }

                        // 7. Workspace Navigation
                        ShortcutCard {
                            icon: "󱂬"
                            title: "Workspaces"
                            ShortcutRow { key: "SUPER + [0-9]"; desc: "Switch Workspace" }
                            ShortcutRow { key: "SUPER+ALT+[0-9]"; desc: "Move Window to WS" }
                            ShortcutRow { key: "SUPER+SHIFT+[0-9]"; desc: "Move Silently to WS" }
                            ShortcutRow { key: "SUPER + Scroll"; desc: "Next / Prev Workspace" }
                            ShortcutRow { key: "CTRL+SUPER+Arrows"; desc: "Next / Prev Workspace" }
                        }

                        // 8. Clipboard & Emojis
                        ShortcutCard {
                            icon: "󰅍"
                            title: "Clipboard & Emojis"
                            ShortcutRow { key: "SUPER + V"; desc: "Clipboard Manager" }
                            ShortcutRow { key: "SUPER + ALT + V"; desc: "Delete Latest Clip" }
                            ShortcutRow { key: "C+S+ALT+V"; desc: "Paste Latest Clip" }
                            ShortcutRow { key: "SUPER + ."; desc: "Emoji Picker" }
                            ShortcutRow { key: "CTRL + ALT + C"; desc: "Clear Notifications" }
                        }

                        // 9. Media & Utilities
                        ShortcutCard {
                            icon: "󰝚"
                            title: "Media & Capture"
                            ShortcutRow { key: "CTRL+SUPER+Space"; desc: "Play / Pause Toggle" }
                            ShortcutRow { key: "CTRL+SUPER+=/-"; desc: "Next / Prev Track" }
                            ShortcutRow { key: "SUPER+SHIFT+M"; desc: "Mute Audio Volume" }
                            ShortcutRow { key: "Print"; desc: "Full Screenshot" }
                            ShortcutRow { key: "SUPER+SHIFT+S"; desc: "Region Screenshot" }
                        }
                }

                // Footer hint
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Text {
                        text: "󰌌"
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                        color: Theme.textDim
                    }

                    Text {
                        text: "Press Super + / or Esc to close this cheat sheet"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }
                }
            }

    // Helper component for clean category card
    component ShortcutCard: Rectangle {
        required property string icon
        required property string title
        default property alias rows: cardCol.children

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        Layout.minimumHeight: Math.max(146, cardCol.implicitHeight + 22)
        implicitHeight: Math.max(146, cardCol.implicitHeight + 22)
        clip: true
        radius: 16
        color: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.72) : Qt.rgba(1.0, 1.0, 1.0, 0.055)
        border.color: Theme.glassCardBorder
        border.width: 1

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 11
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: icon; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.subtext }
                Text {
                    text: title
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.text
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
    }

    // Helper component for clean shortcut row
    component ShortcutRow: RowLayout {
        required property string key
        required property string desc
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredHeight: 19
            Layout.preferredWidth: Math.min(144, keyText.implicitWidth + 10)
            Layout.alignment: Qt.AlignVCenter
            radius: 5
            color: Theme.lightMode ? Qt.rgba(0.0, 0.0, 0.0, 0.07) : Qt.rgba(1.0, 1.0, 1.0, 0.11)
            border.color: Theme.glassCardBorder
            border.width: 1

            Text {
                id: keyText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 134)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: key
                font.family: Theme.fontFamily
                font.pixelSize: 9
                font.bold: true
                color: Theme.text
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: desc
            font.family: Theme.fontFamily
            font.pixelSize: 10
            color: Theme.subtext
        }
    }
}
