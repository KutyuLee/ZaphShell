import QtQuick
import "../.."
import ".."

Rectangle {
    id: gBox
    property bool active: false
    property bool hovered: false
    property bool pressed: false
    property real cornerRadius: 22
    property bool autoLiquidGlass: true

    readonly property bool liquidActive: gBox.autoLiquidGlass && lgSurf.isLiquidActive

    radius: cornerRadius
    color: gBox.liquidActive
        ? "transparent"
        : (gBox.active ? Theme.glassSurfaceActive : (gBox.hovered ? Theme.glassSurfaceHover : Theme.glassCard))
    border.width: gBox.liquidActive ? 0 : 1
    border.color: active ? Theme.glassHighlight : (hovered ? Theme.glassCardBorder : Theme.glassBorder)
    scale: pressed ? 0.97 : 1.0

    LiquidGlassSurface {
        id: lgSurf
        anchors.fill: parent
        z: -1
        visible: gBox.autoLiquidGlass
        cornerRadius: gBox.cornerRadius
        active: gBox.active
        hovered: gBox.hovered
    }

    Behavior on scale {
        NumberAnimation { duration: ShellState.animDur(160, 120); easing.type: ShellState.animPrimaryEase }
    }
    Behavior on color {
        ColorAnimation { duration: ShellState.animDur(200, 140) }
    }
    Behavior on border.color {
        ColorAnimation { duration: ShellState.animDur(200, 140) }
    }
}
