pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs
import qs.screenrecord

// An outline around whatever is being captured, on the output carrying it. It
// is drawn just outside the area, so a captured region or window does not
// contain it and the people watching see nothing; only a whole-output capture,
// which has no outside, shows it at the screen edge.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow { // qmllint disable uncreatable-type
            id: panel
            required property var modelData
            screen: modelData

            // a recording is the shell's own capture and knows its box; a
            // share only has what the picker last told the portal
            readonly property var area: ScreenRecordStatus.recording ? ScreenRecordStatus.area : ScreenShareStatus.area
            readonly property var monitor: Hyprland.monitorFor(panel.screen)
            // a shared window is followed rather than framed once: it moves,
            // resizes and changes monitor while the share runs
            readonly property var toplevel: panel.area?.address ? Hyprland.toplevels.values.find(candidate => candidate.address === panel.area.address) : null
            readonly property string output: panel.toplevel ? (panel.toplevel.monitor?.name ?? "") : (panel.area?.output ?? "")

            visible: (ScreenShareStatus.active || ScreenRecordStatus.recording) && panel.area !== null && panel.output === (panel.monitor?.name ?? "")

            WlrLayershell.namespace: "share-outline"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // nothing here takes a click
            mask: Region {}

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            Rectangle {
                readonly property var ipc: panel.toplevel?.lastIpcObject ?? null
                readonly property int thickness: 3
                readonly property real areaX: this.ipc ? this.ipc.at[0] - (panel.monitor?.lastIpcObject?.x ?? 0) : (panel.area?.x ?? 0)
                readonly property real areaY: this.ipc ? this.ipc.at[1] - (panel.monitor?.lastIpcObject?.y ?? 0) : (panel.area?.y ?? 0)
                readonly property real areaWidth: this.ipc ? this.ipc.size[0] : (panel.area?.w ?? 0)
                readonly property real areaHeight: this.ipc ? this.ipc.size[1] : (panel.area?.h ?? 0)

                x: Math.max(0, this.areaX - this.thickness)
                y: Math.max(0, this.areaY - this.thickness)
                width: Math.min(panel.width - this.x, this.areaWidth + 2 * this.thickness)
                height: Math.min(panel.height - this.y, this.areaHeight + 2 * this.thickness)

                color: "transparent"
                border.color: Theme.alert
                border.width: this.thickness
                radius: Theme.windowRounding
            }
        }
    }
}
