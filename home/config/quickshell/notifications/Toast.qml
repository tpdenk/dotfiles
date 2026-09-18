import Quickshell.Services.Notifications
import QtQuick
import qs

Rectangle {
    id: root
    required property Notification notification

    implicitHeight: content.implicitHeight + 20
    radius: Theme.roundingLarge
    color: Theme.background
    border.width: Theme.borderSize
    border.color: Theme.accent

    Column {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 10
        }
        spacing: 4

        Text {
            width: parent.width
            text: root.notification.summary
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.brightText
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.notification.body
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.text
        }
    }

    Timer {
        interval: root.notification.expireTimeout < 0 ? 5000 : root.notification.expireTimeout
        running: root.notification.expireTimeout !== 0
        onTriggered: root.notification.expire()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.notification.dismiss()
    }
}
