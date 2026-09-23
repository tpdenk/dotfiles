import QtQuick
import qs

// A Stat whose value is copied to the clipboard on click, marked by a copy
// glyph after it.
Stat {
    id: root

    rightInset: copyGlyph.implicitWidth + 6

    Text {
        id: copyGlyph
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        text: Clipboard.icon
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: hover.containsMouse ? Theme.accent : Theme.muted
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Clipboard.copy(root.value)
    }
}
