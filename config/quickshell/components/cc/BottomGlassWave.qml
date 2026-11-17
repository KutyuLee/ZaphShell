import QtQuick
import "../.."

// Single-pass analytical HDR-glow wave shader anchored at the bottom of Medium & Full panels.
// Zero offscreen FBOs, zero OpacityMask passes, zero CurveRenderer tessellation, and fixed quad size for 0-stutter morphing.
Item {
    id: root

    required property real panelWidth
    required property real panelHeight
    required property bool active
    property real cornerRadius: ShellState.centerIslandRadius
    property real intensity: 1.0

    width: Theme.ccMaxWidth
    height: 96

    readonly property real waveScaleX: Math.max(0.01, root.panelWidth / Math.max(1, Theme.ccMaxWidth))
    readonly property real waveScaleY: Math.max(0.01, Math.min(1.0, Math.min(root.panelHeight / 96.0, Math.max(0.54, root.panelHeight / 168.0))))

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height
        xScale: root.waveScaleX
        yScale: root.waveScaleY
    }

    readonly property color rawArtColor: ShellState.mediaArtColor
    readonly property color baseColor: (Theme.lightMode && rawArtColor.r > 0.85 && rawArtColor.g > 0.85 && rawArtColor.b > 0.85)
        ? Qt.rgba(0.38, 0.42, 0.50, 1.0)
        : rawArtColor

    opacity: active ? root.intensity : 0.0
    visible: opacity > 0.005

    Behavior on opacity {
        NumberAnimation { duration: 460; easing.type: Easing.InOutCubic }
    }

    property real backPhase: 0.0
    property real frontPhase: 0.0

    NumberAnimation on backPhase {
        running: root.visible
        from: 0.0
        to: Math.PI * 2.0
        duration: 9200
        loops: Animation.Infinite
    }

    NumberAnimation on frontPhase {
        running: root.visible
        from: 0.0
        to: Math.PI * 2.0
        duration: 11800
        loops: Animation.Infinite
    }

    ShaderEffect {
        id: hdrWaveShader
        anchors.fill: parent

        property color uColor: root.baseColor
        property real uBackPhase: root.backPhase
        property real uFrontPhase: root.frontPhase
        property real uLightMix: Theme.lightMix
        property vector4d uGeom: Qt.vector4d(root.width, root.height, root.panelWidth, root.cornerRadius)
        property vector2d uScale: Qt.vector2d(root.waveScaleX, root.waveScaleY)

        fragmentShader: Qt.resolvedUrl("bottom_wave.frag.qsb")
    }
}
