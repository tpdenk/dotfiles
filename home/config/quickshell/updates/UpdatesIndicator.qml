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
}
