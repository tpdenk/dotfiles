pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

// Every container on the machine: a compose project's services indented under
// it, anything started by hand on its own. Click a row to bring what it stands
// for up or take it down.
SelectList {
    title: "Containers"
    placeholder: DockerStatus.available ? "No containers" : ""
    maxHeight: 220

    model: ScriptModel {
        values: DockerStatus.rows
    }

    delegate: SelectRow {
        id: row
        required property var modelData

        width: ListView.view.width
        indent: row.modelData.member ? 14 : 0
        label: row.modelData.label
        // a stack with only some of it up is in neither state it is meant to
        // be in
        labelColor: row.modelData.running === 0 ? Theme.text : row.modelData.running === row.modelData.total ? Theme.accent : Theme.warning
        onClicked: DockerStatus.activate(row.modelData)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: DockerStatus.stateLabel(row.modelData)
            width: Math.min(implicitWidth, 200)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: DockerStatus.busy(row.modelData) ? Theme.accentSecondary : Theme.muted
        }
    }
}
