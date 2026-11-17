import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import ".."

Rectangle {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.isPresent
    readonly property int percent: dev ? Math.round(dev.percentage <= 1.0 ? dev.percentage * 100 : dev.percentage) : 0
    readonly property bool isCharging: dev && dev.state === UPowerDeviceState.Charging

    visible: hasBattery
    implicitHeight: 20
    implicitWidth: hasBattery ? row.implicitWidth : 0
    color: "transparent"
    border.width: 0

    function getBatteryIcon() {
        if (isCharging) return "󰂄";
        if (percent >= 90) return "󰁹";
        if (percent >= 70) return "󰂀";
        if (percent >= 50) return "󰁾";
        if (percent >= 30) return "󰁼";
        if (percent >= 15) return "󰁺";
        return "󰂃";
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.getBatteryIcon()
            font.family: Theme.iconFont
            font.pixelSize: 14
            color: {
                if (root.isCharging) return Theme.green;
                if (root.percent <= 20) return Theme.red;
                return Theme.text;
            }
        }

        Text {
            visible: ShellState.showBatteryPercent
            text: root.percent + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.text
        }
    }
}
