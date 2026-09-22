pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

// The machine's audio devices of one direction. Clicking a row only moves the
// default device; nothing is routed or muted by it.
SelectList {
    id: root

    property bool inputs: false

    title: root.inputs ? "Inputs" : "Outputs"
    placeholder: root.inputs ? "No inputs" : "No outputs"

    model: ScriptModel {
        values: root.inputs ? AudioStatus.sources : AudioStatus.sinks
    }

    delegate: SelectRow {
        id: row
        required property var modelData

        readonly property bool current: row.modelData === (root.inputs ? AudioStatus.source : AudioStatus.sink)

        width: ListView.view.width
        label: AudioStatus.label(row.modelData)
        labelColor: row.current ? Theme.accent : Theme.text
        onClicked: AudioStatus.makeDefault(row.modelData)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: AudioStatus.percent(row.modelData)
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.current
            text: "default"
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.accent
        }
    }
}
