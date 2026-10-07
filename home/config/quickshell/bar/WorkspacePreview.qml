import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs

// A thumbnail of one workspace, hanging under its chip while the chip is
// hovered. Windows are composited from live toplevel captures laid out at
// their real positions, so it also works for workspaces that are not on
// screen: Hyprland renders those from each window's last frame.
PopupWindow {
    id: root

    required property HyprlandMonitor monitor
    // the chip under the pointer, or null; the preview follows it
    property Item chip: null
    property HyprlandWorkspace workspace: null
    property real stageWidth: 480

    readonly property bool wanted: chip !== null && workspace !== null
    property bool shown: false

    // monitor size in layout coordinates, the space `clients` positions are in
    readonly property real monitorWidth: {
        const t = root.monitor.lastIpcObject?.transform ?? 0;
        return (t % 2 === 1 ? root.monitor.height : root.monitor.width) / root.monitor.scale;
    }
    readonly property real monitorHeight: {
        const t = root.monitor.lastIpcObject?.transform ?? 0;
        return (t % 2 === 1 ? root.monitor.width : root.monitor.height) / root.monitor.scale;
    }
    readonly property real ratio: stageWidth / Math.max(1, monitorWidth)

    onWantedChanged: {
        if (wanted) {
            // window geometry only arrives when asked for
            Hyprland.refreshToplevels();
            outAnim.stop();
            if (shown) {
                // caught mid fade-out while sliding to a neighbour
                card.opacity = 1;
                card.y = 0;
            } else {
                shown = true;
                inAnim.restart();
            }
        } else if (shown) {
            inAnim.stop();
            outAnim.restart();
        }
    }

    // sliding between chips while open: re-anchor instead of re-opening
    onChipChanged: {
        if (chip !== null && shown)
            anchor.updateAnchor();
    }

    visible: shown
    anchor.item: chip
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 8
    color: "transparent"
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        implicitWidth: stage.width + 8
        implicitHeight: stage.height + 8
        radius: Theme.roundingSmall
        color: Theme.base
        border.width: Theme.borderSize
        border.color: Theme.highlight
        opacity: 0

        Rectangle {
            id: stage
            x: 4
            y: 4
            width: root.stageWidth
            height: Math.round(root.monitorHeight * root.ratio)
            radius: Theme.roundingSmall - 2
            color: Theme.background
            clip: true

            Text {
                anchors.centerIn: parent
                visible: windows.count === 0
                text: "empty"
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                color: Theme.muted
            }

            Repeater {
                id: windows
                model: root.workspace?.toplevels ?? null

                ScreencopyView {
                    id: view
                    required property HyprlandToplevel modelData
                    readonly property var info: modelData.lastIpcObject

                    visible: modelData.wayland !== null && info !== undefined && !info.hidden
                    captureSource: visible ? modelData.wayland : null
                    live: true

                    x: Math.round(((info?.at?.[0] ?? 0) - root.monitor.x) * root.ratio)
                    y: Math.round(((info?.at?.[1] ?? 0) - root.monitor.y) * root.ratio)
                    width: Math.max(1, Math.round((info?.size?.[0] ?? 0) * root.ratio))
                    height: Math.max(1, Math.round((info?.size?.[1] ?? 0) * root.ratio))
                    // most recently focused on top; floating windows above tiled ones.
                    // negative z would paint behind `stage`, so count down from a ceiling
                    z: (info?.floating ? 10000 : 0) + Math.max(0, 1000 - (info?.focusHistoryID ?? 1000))
                }
            }
        }
    }

    ParallelAnimation {
        id: inAnim
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durationIn
        }
        NumberAnimation {
            target: card
            property: "y"
            from: -4
            to: 0
            duration: Theme.durationIn
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: outAnim
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: Theme.durationOut
        }
        ScriptAction {
            script: root.shown = false
        }
    }
}
