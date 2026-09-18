import QtQuick
import qs

// Bar entry: the battery at its current level when this machine has one, then
// the power profile. Click toggles the dropdown.
Item {
    id: root

    readonly property color tint: PowerStatus.expanded ? Theme.brightText : PowerStatus.low ? Theme.accentSecondary : PowerStatus.discharging ? Theme.accent : Theme.muted

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            // the plug stands in when there is nothing else to show, so the
            // entry never collapses to an unclickable zero width
            text: PowerStatus.batteryIcon || (PowerStatus.profileIcon ? "" : PowerStatus.fallbackIcon)
            font.family: Theme.fontFamily
            font.pointSize: Theme.h1Size
            color: root.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
            text: PowerStatus.profileIcon
            font.family: Theme.fontFamily
            font.pointSize: Theme.h1Size
            // balanced is the profile nobody chose
            color: PowerStatus.expanded ? Theme.brightText : PowerStatus.profileIsDefault ? Theme.muted : Theme.accent
        }
    }

    MouseArea {
        anchors {
            fill: parent
            margins: -4
        }
        onClicked: Panels.toggle("power")
    }
}
