import QtQuick
import ".."

// Shared Liquid Glass optical refraction + adaptive smoked contrast ShaderEffect
ShaderEffect {
    id: root

    required property var desktopSource
    required property real screenX
    required property real screenY
    required property real screenW
    required property real screenH
    required property real cornerRadius

    property real screenWidth: ShellState.mainScreenWidth
    property real screenHeight: ShellState.mainScreenHeight
    property color tintColor: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(0.14, 0.16, 0.22, 0.05)
    property color rimColor: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.92) : Qt.rgba(1.0, 1.0, 1.0, 0.85)
    property real refraction: 4.2
    property real bevelDepth: 4.8
    property real bevelWidth: 0.18
    property real aberration: 0.08
    property real frost: 1.05

    property var uSource: desktopSource
    property vector4d uBounds: Qt.vector4d(
        screenX / Math.max(1, screenWidth),
        screenY / Math.max(1, screenHeight),
        screenW / Math.max(1, screenWidth),
        screenH / Math.max(1, screenHeight)
    )
    property color uTint: tintColor
    property color uRimColor: rimColor
    property size uBoxSize: Qt.size(Math.max(1, width), Math.max(1, height))
    property size uTexSize: Qt.size(Math.max(1, screenWidth), Math.max(1, screenHeight))
    property real uRadius: cornerRadius
    property real uRefraction: refraction
    property real uBevelDepth: bevelDepth
    property real uBevelWidth: bevelWidth
    property real uAberration: aberration
    property real uFrost: frost

    fragmentShader: Qt.resolvedUrl("liquid_glass.frag.qsb")
}
