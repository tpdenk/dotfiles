import QtQuick
import qs
import qs.widgets

// Bar pill for tailscale: the logo and how many peers are online, dimmed
// while this node is off the tailnet. Click toggles the tailnet panel.
Pill {
    id: root

    readonly property bool shown: TailscaleStatus.available && (TailscaleStatus.running || Panels.statusExpanded || highlight)
    visible: shown
    bare: true

    readonly property color tint: TailscaleStatus.running ? Theme.accent : Theme.muted

    highlight: Panels.open === "tailscale"

    onClicked: Panels.toggle("tailscale")

    // Nerd Fonts has no tailscale glyph, so the logo is drawn: a 3x3 grid of
    // dots, the solid ones forming a "T"
    Grid {
        anchors.verticalCenter: parent.verticalCenter
        columns: 3
        spacing: 2

        Repeater {
            model: [false, false, false, true, true, true, false, true, false]

            Rectangle {
                required property bool modelData
                width: 4
                height: 4
                radius: 2
                color: root.tint
                opacity: modelData ? 1 : 0.3
            }
        }
    }

    // declared here rather than through `label`, which Pill places before
    // its extra children
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: TailscaleStatus.label
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: TailscaleStatus.running ? Theme.brightText : Theme.muted
    }
}
