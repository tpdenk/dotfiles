import QtQuick
import qs
import qs.widgets

Pill {
    id: root

    readonly property bool packagesShown: UpdatesStatus.count > 0 || UpdatesStatus.failed
    readonly property bool firmwareShown: FirmwareStatus.devices.length > 0 || FirmwareStatus.failed

    visible: packagesShown || firmwareShown

    glyph: packagesShown ? UpdatesStatus.icon : ""
    label: packagesShown ? UpdatesStatus.label : ""
    highlight: Panels.open === "updates"
    glyphColor: UpdatesStatus.failed ? Theme.alert : Theme.accent
    labelColor: Theme.brightText

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
        visible: root.firmwareShown
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: FirmwareStatus.icon
            font.family: Theme.fontFamily
            font.pointSize: Theme.h2Size
            color: FirmwareStatus.failed ? Theme.alert : FirmwareStatus.blocked > 0 ? Theme.warning : Theme.accentSecondary
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
