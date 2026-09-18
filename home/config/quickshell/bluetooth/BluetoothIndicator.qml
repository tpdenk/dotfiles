import QtQuick
import qs

// Bar icon for the bluetooth controller; click toggles the details panel.
Text {
    id: root

    text: BluetoothStatus.icon
    font.family: Theme.fontFamily
    font.pointSize: Theme.h1Size
    color: BluetoothStatus.expanded ? Theme.brightText : BluetoothStatus.connectedCount > 0 ? Theme.accent : Theme.muted

    MouseArea {
        anchors {
            fill: parent
            margins: -4
        }
        onClicked: Panels.toggle("bluetooth")
    }
}
