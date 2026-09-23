pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

// Every other node on the tailnet, reachable ones first. Click one to copy its
// address.
SelectList {
    title: TailscaleStatus.running ? "Peers" : "Tailscale off"
    placeholder: TailscaleStatus.running ? "No peers" : ""
    maxHeight: 220

    model: ScriptModel {
        values: TailscaleStatus.running ? TailscaleStatus.peers : []
    }

    delegate: SelectRow {
        id: row
        required property var modelData

        width: ListView.view.width
        label: row.modelData.name
        labelColor: row.modelData.exitNode ? Theme.accentSecondary : row.modelData.online ? Theme.accent : Theme.text
        onClicked: Clipboard.copy(row.modelData.address)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.online ? row.modelData.os : "offline"
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.address
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Clipboard.icon
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }
    }
}
