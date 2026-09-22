pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

SelectList {
    title: "Firmware"
    placeholder: FirmwareStatus.failed ? "fw-updates could not be run" : "Firmware is current"

    model: ScriptModel {
        values: FirmwareStatus.devices
    }

    delegate: SelectRow {
        id: row
        required property var modelData

        width: ListView.view.width
        label: row.modelData.name
        onClicked: FirmwareStatus.update(row.modelData)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: FirmwareStatus.versionLabel(row.modelData)
            width: Math.min(implicitWidth, 210)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }
    }
}
