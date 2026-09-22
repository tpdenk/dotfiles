import QtQuick
import qs
import qs.widgets

Pill {
    id: root

    glyph: UpdatesStatus.icon
    label: UpdatesStatus.label
    highlight: UpdatesStatus.expanded
    glyphColor: UpdatesStatus.failed ? Theme.alert : UpdatesStatus.count > 0 ? Theme.accent : Theme.muted
    labelColor: UpdatesStatus.count > 0 ? Theme.brightText : Theme.muted

    onClicked: Panels.toggle("updates")

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: UpdatesStatus.kernelUpdate
        text: UpdatesStatus.kernelIcon
        font.family: Theme.fontFamily
        font.pointSize: Theme.h2Size
        color: Theme.warning
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: FirmwareStatus.count > 0 || FirmwareStatus.failed
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: FirmwareStatus.icon
            font.family: Theme.fontFamily
            font.pointSize: Theme.h2Size
            color: FirmwareStatus.failed ? Theme.alert : Theme.accentSecondary
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: FirmwareStatus.label
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.brightText
        }
    }
}
