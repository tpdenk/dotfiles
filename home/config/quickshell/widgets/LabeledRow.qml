import QtQuick
import qs

// `label` on the left, the caller's controls in a row on the right.
Item {
    id: root

    property string label
    default property alias content: row.data

    implicitHeight: Math.max(labelText.implicitHeight, row.implicitHeight)

    Text {
        id: labelText
        anchors {
            left: parent.left
            right: row.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        text: root.label
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.muted
    }

    Row {
        id: row
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 6
    }
}
