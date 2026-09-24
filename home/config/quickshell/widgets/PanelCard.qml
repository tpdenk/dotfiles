import QtQuick
import qs

// The shell's dropdown card: title, divider, then the caller's rows.
Rectangle {
    id: root

    property string title
    property string subtitle
    // `data`, not `children`: a consumer may declare a Timer or Connections
    // alongside its rows
    default property alias content: column.data

    // wide enough for a full IPv6 address with prefix on one line
    implicitWidth: 400
    implicitHeight: column.implicitHeight + 24
    radius: Theme.windowRounding
    color: Theme.background
    border.width: 1
    border.color: Theme.highlight

    Column {
        id: column
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 6

        Item {
            width: column.width
            implicitHeight: titleText.implicitHeight

            Text {
                id: titleText
                text: root.title
                font.family: Theme.fontFamily
                font.pointSize: Theme.h2Size
                color: Theme.brightText
            }

            Text {
                anchors {
                    right: parent.right
                    left: titleText.right
                    leftMargin: 12
                    baseline: titleText.baseline
                }
                visible: text !== ""
                text: root.subtitle
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                color: Theme.muted
            }
        }

        Divider {
            width: column.width
        }
    }
}
