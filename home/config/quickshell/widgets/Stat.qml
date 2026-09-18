import QtQuick
import qs

// `label    value` line, value right aligned and elided
Item {
    id: root

    property string label
    property string value

    implicitHeight: valueText.implicitHeight

    Text {
        id: labelText
        anchors.left: parent.left
        text: root.label
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.muted
    }

    Text {
        id: valueText
        anchors {
            left: labelText.right
            leftMargin: 12
            right: parent.right
        }
        text: root.value
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.text
    }
}
