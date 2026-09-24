pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs
import qs.widgets

Pill {
    id: root
    required property HyprlandMonitor monitor
    property real maxWidth: 0

    interactive: false

    readonly property var focused: {
        const t = Hyprland.activeToplevel;
        return t && t.workspace && t.workspace === root.monitor?.activeWorkspace ? t : null;
    }

    Repeater {
        model: ScriptModel {
            // ids < 0 are special workspaces
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            id: chip
            required property HyprlandWorkspace modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(height, label.implicitWidth + 8)
            implicitHeight: 18
            radius: height / 2
            color: modelData.active ? Qt.alpha(Theme.accent, 0.3) : hover.containsMouse ? Theme.highlight : "transparent"

            Text {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.name
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                font.bold: chip.modelData.active
                color: chip.modelData.active ? Theme.accent : chip.modelData.urgent ? Theme.attention : Theme.text
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.modelData.activate()
            }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.focused !== null
        width: 1
        height: 12
        color: Theme.highlight
    }

    Text {
        id: app
        anchors.verticalCenter: parent.verticalCenter
        visible: root.focused !== null && text !== ""
        text: root.focused?.wayland?.appId ?? ""
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.muted
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.focused !== null
        text: root.focused?.title ?? ""
        width: {
            const room = root.maxWidth > 0 ? root.maxWidth - x - 16 : Infinity;
            return Math.max(0, Math.min(implicitWidth, 40 * fontMetrics.averageCharacterWidth, room));
        }
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.text

        FontMetrics {
            id: fontMetrics
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
        }
    }
}
