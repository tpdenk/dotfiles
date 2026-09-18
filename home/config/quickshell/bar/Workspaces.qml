pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs

// Workspaces living on `monitor`, ordered by id; the monitor's active one is highlighted.
Row {
    id: root
    required property HyprlandMonitor monitor
    spacing: 4

    Repeater {
        model: ScriptModel {
            // ids < 0 are special workspaces
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            required property HyprlandWorkspace modelData

            width: Math.max(height, label.implicitWidth + 12)
            height: 20
            radius: 4
            color: modelData.active ? Qt.alpha(HyprColors.activeBorder, 0.25) : "transparent"

            Text {
                id: label
                anchors.centerIn: parent
                text: parent.modelData.name
                font.pixelSize: 13
                color: parent.modelData.active ? HyprColors.activeBorder : HyprColors.inactiveBorder
            }

            MouseArea {
                anchors.fill: parent
                onClicked: parent.modelData.activate()
            }
        }
    }
}
