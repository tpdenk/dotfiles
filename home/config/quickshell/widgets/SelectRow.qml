import QtQuick
import qs

// One clickable row: name on the left, caller's meta items on the right.
Rectangle {
    id: root

    property string label
    property color labelColor: Theme.text
    // indent for a row nested under another
    property real indent: 0
    default property alias meta: metaRow.data

    signal clicked

    height: 24
    radius: Theme.roundingSmall
    color: hover.containsMouse ? Theme.highlight : "transparent"

    Text {
        anchors {
            left: parent.left
            leftMargin: 6 + root.indent
            right: metaRow.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        text: root.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: root.labelColor
    }

    Row {
        id: metaRow
        // above `hover`, so a meta item with its own MouseArea takes the click
        z: 1
        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        spacing: 6
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
