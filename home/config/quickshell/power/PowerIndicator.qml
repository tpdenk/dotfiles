import QtQuick
import qs
import qs.widgets

// Bar pill: on a machine with a battery, the battery at its current level with
// its charge as a percentage, then the power profile; on one without, the
// profile alone. Click toggles the dropdown.
Pill {
    id: root

    readonly property color tint: PowerStatus.low ? Theme.accentSecondary : PowerStatus.discharging ? Theme.accent : Theme.muted

    // the plug stands in when there is neither a battery nor a profile daemon,
    // so the entry never collapses to nothing
    glyph: PowerStatus.batteryIcon || PowerStatus.profileIcon || PowerStatus.fallbackIcon
    label: PowerStatus.barLabel
    glyphColor: PowerStatus.hasBattery ? root.tint : Theme.accent
    labelColor: PowerStatus.hasBattery ? root.tint : Theme.text
    highlight: PowerStatus.expanded

    onClicked: Panels.toggle("power")

    // the battery took the first slot, so the profile trails it
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: PowerStatus.hasBattery && text !== ""
        text: PowerStatus.profileIcon
        font.family: Theme.fontFamily
        font.pointSize: Theme.h2Size
        color: Theme.accent
    }
}
