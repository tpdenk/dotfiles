pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

// Devices this controller knows or has just seen. Click one to pair, connect
// or disconnect it.
SelectList {
    title: BluetoothStatus.enabled ? "Devices" : "Bluetooth off"
    placeholder: BluetoothStatus.enabled ? "Scanning…" : ""

    model: ScriptModel {
        values: BluetoothStatus.enabled ? BluetoothStatus.devices : []
    }

    delegate: SelectRow {
        id: row
        required property var modelData

        width: ListView.view.width
        label: BluetoothStatus.label(row.modelData)
        labelColor: row.modelData.connected ? Theme.accent : row.modelData.paired ? Theme.brightText : Theme.text
        onClicked: BluetoothStatus.activate(row.modelData)

        // only peripherals that report a battery over BlueZ have one
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.modelData.batteryAvailable
            text: `${Math.round(row.modelData.battery * 100)}%`
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: BluetoothStatus.stateLabel(row.modelData)
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }
    }
}
