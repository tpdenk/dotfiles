import QtQuick
import qs

// The shell's dropdown card: title, divider, then the caller's rows.
Rectangle {
    id: root

    property string title
    // `data`, not `children`: a consumer may declare a Timer or Connections
    // alongside its rows
    default property alias content: column.data

    // wide enough for a full IPv6 address with prefix on one line
    implicitWidth: 400
    implicitHeight: column.implicitHeight + 24
    radius: Theme.roundingLarge
    color: Theme.background
    border.width: Theme.borderSize
    border.color: Theme.accent

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 6

        Text {
            text: root.title
            font.family: Theme.fontFamily
            font.pointSize: Theme.h2Size
            color: Theme.brightText
        }

        Divider {
            width: column.width
        }
    }
}
