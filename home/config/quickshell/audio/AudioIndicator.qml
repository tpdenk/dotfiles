import QtQuick
import qs

// Bar icon for the default output; click toggles the details panel.
Text {
    id: root

    text: AudioStatus.icon
    font.family: Theme.fontFamily
    font.pointSize: Theme.h1Size
    color: AudioStatus.expanded ? Theme.brightText : AudioStatus.muted ? Theme.muted : Theme.accent

    MouseArea {
        anchors {
            fill: parent
            margins: -4
        }
        onClicked: Panels.toggle("audio")
    }
}
