import QtQuick
import qs
import qs.widgets

// Bar pill for the mouse: its charge, and a bolt while it charges. Absent
// while the mouse cannot be reached.
Pill {
    readonly property bool shown: MouseStatus.connected && (MouseStatus.low || MouseStatus.charging || Panels.statusExpanded)
    visible: shown
    bare: true
    interactive: false

    glyph: MouseStatus.icon
    label: MouseStatus.label
    glyphColor: MouseStatus.low ? Theme.attention : Theme.accent
    labelColor: MouseStatus.low ? Theme.attention : Theme.text

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: MouseStatus.charging
        text: MouseStatus.chargingIcon
        font.family: Theme.fontFamily
        font.pointSize: Theme.h2Size
        color: Theme.accent
    }
}
