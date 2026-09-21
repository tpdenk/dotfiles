import qs
import qs.widgets

// Bar pill for the primary connection: its icon and what it is connected to.
// Click toggles the details panel.
Pill {
    id: root

    glyph: NetworkStatus.icon
    label: NetworkStatus.barLabel
    // an SSID can be 32 characters of anything
    labelLimit: 140
    highlight: NetworkStatus.expanded
    glyphColor: NetworkStatus.primaryConnected ? Theme.accent : Theme.muted
    labelColor: NetworkStatus.primaryConnected ? Theme.text : Theme.muted

    onClicked: Panels.toggle("network")
}
