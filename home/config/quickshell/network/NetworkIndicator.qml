import qs
import qs.widgets

// Bar pill for the primary connection: its icon and what it is connected to.
// Click toggles the details panel.
Pill {
    bare: true
    glyph: NetworkStatus.icon
    label: Panels.statusExpanded || highlight ? NetworkStatus.barLabel : ""
    // an SSID can be 32 characters of anything
    labelLimit: 140
    highlight: Panels.open === "network"
    glyphColor: NetworkStatus.primaryConnected ? Theme.accent : Theme.muted
    labelColor: NetworkStatus.primaryConnected ? Theme.text : Theme.muted

    onClicked: Panels.toggle("network")
}
