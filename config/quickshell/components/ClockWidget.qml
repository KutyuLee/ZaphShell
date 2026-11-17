import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."

Rectangle {
    id: root

    implicitHeight: 20
    implicitWidth: clockRow.implicitWidth
    color: "transparent"
    border.width: 0

    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    readonly property string timeFormat: {
        if (ShellState.use24HourClock) {
            return ShellState.showClockSeconds ? "HH:mm:ss" : "HH:mm";
        } else {
            return ShellState.showClockSeconds ? "hh:mm:ss AP" : "hh:mm AP";
        }
    }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8
        layer.enabled: ShellState.liquidGlassEnabled
        layer.effect: DropShadow {
            verticalOffset: 1
            radius: 4
            samples: 9
            color: Qt.rgba(0, 0, 0, Theme.lightMode ? 0.22 : 0.78)
        }

        Text {
            id: dateText
            text: Qt.formatDate(sysClock.date, "ddd MMM d")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.subtext
        }

        // Fixed-width container + tabular digits so ticking seconds never jump
        Item {
            id: timeContainer
            readonly property int preferredTimeWidth: {
                if (ShellState.use24HourClock) {
                    return ShellState.showClockSeconds ? 58 : 38;
                } else {
                    return ShellState.showClockSeconds ? 80 : 60;
                }
            }
            Layout.preferredWidth: preferredTimeWidth
            Layout.preferredHeight: 20

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: Qt.formatTime(sysClock.date, root.timeFormat)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeNormal
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: Theme.text
            }
        }
    }
}
