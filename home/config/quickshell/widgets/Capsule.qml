import QtQuick
import qs

Rectangle {
    id: root

    default property alias content: row.data

    implicitWidth: row.implicitWidth
    implicitHeight: 24
    radius: height / 2
    color: Theme.base
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durationIn
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
    }
}
