import QtQuick
import QtQuick.Layouts
import "../.."

Rectangle {
    id: gBadge
    property bool active: false
    property bool hovered: false
    property bool pressed: false
    property string icon: ""
    property int iconSize: 16
    property int badgeSize: 36

    width: badgeSize
    height: badgeSize
    implicitWidth: badgeSize
    implicitHeight: badgeSize
    Layout.preferredWidth: badgeSize
    Layout.preferredHeight: badgeSize
    radius: badgeSize / 2
    color: active ? Theme.badgeBgActive : Theme.badgeBgInactive
    border.width: 1
    border.color: active ? Theme.badgeBgActive : Theme.glassBorder
    scale: pressed ? 0.90 : (hovered ? 1.06 : 1.0)

    Behavior on scale { NumberAnimation { duration: ShellState.animDur(160, 110); easing.type: ShellState.animPrimaryEase } }
    Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
    Behavior on border.color { ColorAnimation { duration: ShellState.animDur(220, 150) } }

    Text {
        anchors.centerIn: parent
        text: gBadge.icon
        font.family: Theme.iconFont
        font.pixelSize: gBadge.iconSize
        color: gBadge.active ? Theme.badgeFgActive : Theme.badgeFgInactive
        Behavior on color { ColorAnimation { duration: ShellState.animDur(220, 150) } }
    }
}
