pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    // Live-configurable appearance metrics (persisted via ShellState to ~/.cache/quickshell/state.json)
    property bool lightMode: false
    property int frameThickness: 0
    readonly property int screenCornerRadius: 34

    // Smooth 320ms interpolation factor (0.0 = Dark Mode, 1.0 = Light Mode)
    property real lightMix: lightMode ? 1.0 : 0.0
    Behavior on lightMix {
        NumberAnimation {
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }

    function mix(cDark, cLight) {
        const t = root.lightMix;
        return Qt.rgba(
            cDark.r + (cLight.r - cDark.r) * t,
            cDark.g + (cLight.g - cDark.g) * t,
            cDark.b + (cLight.b - cDark.b) * t,
            cDark.a + (cLight.a - cDark.a) * t
        );
    }

    // Honor MagicOS Pitch-Black Translucent Glass (Dark) <-> Crisp Pure White Translucent Glass (Light)
    readonly property color frameColor: mix(
        Qt.rgba(0.0, 0.0, 0.0, 0.74),
        Qt.rgba(1.0, 1.0, 1.0, 0.88)
    )
    readonly property color islandTopColor: mix(
        Qt.rgba(0.0, 0.0, 0.0, 0.80),
        Qt.rgba(1.0, 1.0, 1.0, 0.93)
    )
    readonly property color islandMidColor: mix(
        Qt.rgba(0.0, 0.0, 0.0, 0.74),
        Qt.rgba(1.0, 1.0, 1.0, 0.88)
    )
    readonly property color islandBottomColor: mix(
        Qt.rgba(0.0, 0.0, 0.0, 0.62),
        Qt.rgba(1.0, 1.0, 1.0, 0.80)
    )
    readonly property color borderStroke: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.11),
        Qt.rgba(0.0, 0.0, 0.0, 0.09)
    )
    readonly property color glassSurface: frameColor
    readonly property color glassCard: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.018),
        Qt.rgba(0.0, 0.0, 0.0, 0.04)
    )
    readonly property color glassSurfaceHover: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.042),
        Qt.rgba(0.0, 0.0, 0.0, 0.07)
    )
    readonly property color glassSurfaceActive: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.052),
        Qt.rgba(0.0, 0.0, 0.0, 0.095)
    )
    readonly property color glassBorder: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.048),
        Qt.rgba(0.0, 0.0, 0.0, 0.065)
    )
    readonly property color glassHighlight: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.11),
        Qt.rgba(0.0, 0.0, 0.0, 0.12)
    )
    readonly property color glassCardBorder: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.07),
        Qt.rgba(0.0, 0.0, 0.0, 0.08)
    )
    readonly property color segmentedTrack: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.022),
        Qt.rgba(0.0, 0.0, 0.0, 0.045)
    )

    // Minimalist Monochrome Platinum & Iconic White Slider Semantics
    readonly property color badgeBgActive: accent
    readonly property color badgeFgActive: textInverse
    readonly property color badgeBgInactive: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.035),
        Qt.rgba(0.0, 0.0, 0.0, 0.055)
    )
    readonly property color badgeFgInactive: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.90),
        Qt.rgba(0.10, 0.11, 0.14, 0.88)
    )
    readonly property color sliderTrack: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.042),
        Qt.rgba(0.0, 0.0, 0.0, 0.065)
    )
    readonly property color sliderFill: mix(
        Qt.rgba(1.0, 1.0, 1.0, 0.92),
        Qt.rgba(0.10, 0.11, 0.14, 0.92)
    )
    readonly property color sliderFillFg: mix(
        Qt.rgba(0.09, 0.10, 0.12, 1.0),
        Qt.rgba(0.97, 0.97, 0.98, 1.0)
    )

    // System Accent Highlights
    readonly property color blueContainer: accentSoft
    readonly property color blueOnContainer: accent
    readonly property color green: mix(Qt.rgba(0.19, 0.82, 0.35, 1.0), Qt.rgba(0.12, 0.65, 0.26, 1.0))
    readonly property color red: mix(Qt.rgba(1.0, 0.27, 0.23, 1.0), Qt.rgba(0.86, 0.18, 0.15, 1.0))
    readonly property color redContainer: "#26ff453a"

    // Apple System Typography Colors (Smoothly interpolates Crisp White <-> Deep Charcoal)
    readonly property color text: mix(
        Qt.rgba(0.97, 0.97, 0.98, 1.0),
        Qt.rgba(0.09, 0.10, 0.13, 1.0)
    )
    readonly property color subtext: mix(
        Qt.rgba(0.76, 0.76, 0.80, 1.0),
        Qt.rgba(0.28, 0.30, 0.36, 1.0)
    )
    readonly property color textDim: mix(
        Qt.rgba(0.56, 0.56, 0.60, 1.0),
        Qt.rgba(0.42, 0.44, 0.50, 1.0)
    )
    readonly property color textInverse: mix(
        Qt.rgba(0.11, 0.11, 0.12, 1.0),
        Qt.rgba(0.97, 0.97, 0.98, 1.0)
    )
    readonly property color accentDark: "#F4F4F6"
    readonly property color accentLight: "#18181B"
    readonly property color accent: mix(accentDark, accentLight)
    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, lightMode ? 0.16 : 0.22)

    // Desktop Frame & Deforming Morph Geometry (Super-rounded GNOME / M3 style)
    property string mainMonitorName: Quickshell.env("QUICKSHELL_MONITOR") || "DP-1"
    readonly property int panelRadius: screenCornerRadius
    readonly property int launcherCardWidth: 520
    readonly property int launcherMaxHeight: 470
    readonly property int launcherCardHeight: 470
    readonly property int ccMaxWidth: 560
    readonly property int ccCardHeight: 392
    readonly property int volumeOsdWidth: 64
    readonly property int volumeOsdHeight: 300
    readonly property int notifCardWidth: 360
    readonly property int notifCardHeight: 88
    readonly property int sysMenuWidth: 264
    readonly property int sysMenuHeight: 424
    readonly property int weatherCardWidth: 340
    readonly property int weatherMaxHeight: 454
    readonly property int notifCenterWidth: 360
    readonly property int notifCenterHeight: 460

    // Apple-style Smooth Proportional Sans-Serif Font + Nerd Font for Icons
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int fontSizeTiny: 11
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeNormal: 13

    // Layout Dimensions (Floating capsule top bar + rounded cards)
    readonly property int barHeight: 38
    readonly property int barTopGap: 8
    readonly property int barMarginX: 12
    readonly property int barBottomY: barTopGap + barHeight
    readonly property real barRadius: barHeight / 2
    readonly property int radiusPill: 9999
    readonly property int radiusLarge: 28
    readonly property int radiusSmall: 16
}
