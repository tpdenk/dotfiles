pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.widgets

// One pill holding every workspace living on `monitor`, ordered by id; the
// monitor's active one is the highlighted number.
Pill {
    id: root
    required property HyprlandMonitor monitor

    Repeater {
        model: ScriptModel {
            // ids < 0 are special workspaces
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            required property HyprlandWorkspace modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(height, label.implicitWidth + 6)
            implicitHeight: 18
            radius: height / 2
            color: modelData.active ? Qt.alpha(Theme.accent, 0.3) : "transparent"

            Text {
                id: label
                anchors.centerIn: parent
                text: parent.modelData.name
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                color: parent.modelData.active ? Theme.accent : Theme.muted
            }

            MouseArea {
                anchors.fill: parent
                onClicked: parent.modelData.activate()
            }
        }
    }
}
