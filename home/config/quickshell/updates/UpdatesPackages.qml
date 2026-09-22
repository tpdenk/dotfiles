pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

SelectList {
    title: "Waiting"
    placeholder: UpdatesStatus.failed ? "pkg-updates could not be run" : "Everything is up to date"
    maxHeight: 200

    model: ScriptModel {
        values: UpdatesStatus.groups
    }

    delegate: SelectRow {
        id: row
        required property var modelData

        width: ListView.view.width
        label: UpdatesStatus.groupLabel(row.modelData)
        labelColor: row.modelData.kernel ? Theme.warning : Theme.text
        onClicked: UpdatesStatus.update(row.modelData)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: UpdatesStatus.versionLabel(row.modelData)
            width: Math.min(implicitWidth, 210)
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }
    }
}
