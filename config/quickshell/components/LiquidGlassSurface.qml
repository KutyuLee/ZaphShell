import QtQuick
import ".."

// Drop-in Liquid Glass surface layer that automatically discovers the nearest window-level
// `liquidGlassHost: true` ancestor and maps this item's exact live bounds to screen space.
Item {
    id: root

    property var captureSource: (hostItem && hostItem.liquidSource !== undefined) ? hostItem.liquidSource : null
    readonly property bool hostReady: (hostItem && hostItem.liquidSourceReady !== undefined) ? hostItem.liquidSourceReady : true
    property real windowOriginX: (hostItem && hostItem.liquidOriginX !== undefined) ? hostItem.liquidOriginX : 0
    property real windowOriginY: (hostItem && hostItem.liquidOriginY !== undefined) ? hostItem.liquidOriginY : 0
    readonly property real texWidth: (hostItem && hostItem.liquidTexWidth !== undefined) ? hostItem.liquidTexWidth : ShellState.mainScreenWidth
    readonly property real texHeight: (hostItem && hostItem.liquidTexHeight !== undefined) ? hostItem.liquidTexHeight : ShellState.mainScreenHeight
    readonly property real hostLayoutRev: (hostItem && hostItem.liquidLayoutRev !== undefined) ? hostItem.liquidLayoutRev : 0

    property var hostItem: null
    property real cornerRadius: 16
    property bool active: false
    property bool hovered: false
    property bool onlyWhenHighlighted: false
    property real bevelWidth: Math.min(0.24, Math.max(0.14, 8.0 / Math.max(20, Math.min(width, height))))
    property real frost: 0.65

    property color restTint: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.16) : Qt.rgba(0.16, 0.19, 0.26, 0.08)
    property color hoverTint: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.24) : Qt.rgba(0.24, 0.28, 0.36, 0.15)
    property color activeTint: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.34) : Qt.rgba(0.28, 0.34, 0.46, 0.24)
    property color restRim: Theme.lightMode ? Qt.rgba(1.0, 1.0, 1.0, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.72)
    property color hoverRim: Qt.rgba(1.0, 1.0, 1.0, 0.90)

    readonly property bool isLiquidActive: ShellState.liquidGlassEnabled && root.captureSource !== null && root.hostReady && (!root.onlyWhenHighlighted || root.active || root.hovered)

    property real mappedX: 0
    property real mappedY: 0
    property real mappedW: Math.max(1, width)
    property real mappedH: Math.max(1, height)

    function findHost() {
        let p = root.parent;
        while (p) {
            if (p.liquidGlassHost === true) {
                root.hostItem = p;
                return;
            }
            p = p.parent;
        }
    }

    function syncScreenBounds() {
        if (!root.isLiquidActive || !root.visible || width <= 1 || height <= 1) return;
        const p0 = root.mapToItem(null, 0, 0);
        const p1 = root.mapToItem(null, root.width, root.height);
        mappedX = root.windowOriginX + p0.x;
        mappedY = root.windowOriginY + p0.y;
        mappedW = Math.max(1, Math.abs(p1.x - p0.x));
        mappedH = Math.max(1, Math.abs(p1.y - p0.y));
    }

    Component.onCompleted: {
        findHost();
        Qt.callLater(syncScreenBounds);
    }
    onParentChanged: {
        findHost();
        Qt.callLater(syncScreenBounds);
    }
    onXChanged: syncScreenBounds()
    onYChanged: syncScreenBounds()
    onWidthChanged: syncScreenBounds()
    onHeightChanged: syncScreenBounds()
    onVisibleChanged: {
        if (visible) {
            syncScreenBounds();
            Qt.callLater(syncScreenBounds);
        }
    }
    onHostLayoutRevChanged: syncScreenBounds()
    onWindowOriginXChanged: syncScreenBounds()
    onWindowOriginYChanged: syncScreenBounds()
    onCaptureSourceChanged: Qt.callLater(syncScreenBounds)
    onIsLiquidActiveChanged: {
        if (isLiquidActive) {
            syncScreenBounds();
            Qt.callLater(syncScreenBounds);
        }
    }

    LiquidGlassEffect {
        anchors.fill: parent
        visible: root.isLiquidActive
        desktopSource: root.captureSource
        screenX: root.mappedX
        screenY: root.mappedY
        screenW: root.mappedW
        screenH: root.mappedH
        screenWidth: root.texWidth
        screenHeight: root.texHeight
        cornerRadius: root.cornerRadius
        bevelWidth: root.bevelWidth
        frost: root.frost
        tintColor: root.active ? root.activeTint : (root.hovered ? root.hoverTint : root.restTint)
        rimColor: (root.active || root.hovered) ? root.hoverRim : root.restRim
    }
}
