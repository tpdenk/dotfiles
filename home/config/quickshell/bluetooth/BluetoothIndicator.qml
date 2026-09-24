import qs
import qs.widgets

// Bar pill for the bluetooth controller: its icon and what it is connected to.
// Click toggles the details panel.
Pill {
    readonly property bool shown: BluetoothStatus.present && (BluetoothStatus.connectedCount > 0 || Panels.statusExpanded || highlight)
    visible: shown
    bare: true

    glyph: BluetoothStatus.icon
    label: Panels.statusExpanded || highlight ? BluetoothStatus.barLabel : ""
    // a device names itself whatever it likes
    labelLimit: 140
    highlight: Panels.open === "bluetooth"
    glyphColor: BluetoothStatus.connectedCount > 0 ? Theme.accent : Theme.muted
    labelColor: BluetoothStatus.connectedCount > 0 ? Theme.text : Theme.muted

    onClicked: Panels.toggle("bluetooth")
}
