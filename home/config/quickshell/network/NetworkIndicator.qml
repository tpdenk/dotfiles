import QtQuick
import qs

// Bar icon for the primary connection; click toggles the details panel.
Text {
    id: root

    text: NetworkStatus.icon
    font.family: Theme.fontFamily
    font.pointSize: Theme.h1Size
    color: NetworkStatus.expanded ? Theme.brightText : NetworkStatus.primaryConnected ? Theme.accent : Theme.muted

    MouseArea {
        anchors {
            fill: parent
            margins: -4
        }
        onClicked: NetworkStatus.expanded = !NetworkStatus.expanded
    }
}
