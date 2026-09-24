import Quickshell.Services.Notifications
import QtQuick
import qs

Rectangle {
    id: root
    required property Notification notification
    property bool popup: false

    readonly property var buttons: root.notification.actions.filter(a => a.identifier !== "default")
    readonly property string image: NotificationCenter.imageOf(root.notification)
    readonly property bool hovered: mouse.containsMouse || close.containsMouse

    implicitHeight: Math.max(content.implicitHeight, icon.visible ? icon.height : 0) + 20
    radius: Theme.windowRounding
    color: root.popup ? Theme.background : root.hovered ? Theme.highlight : "transparent"
    border.width: root.popup ? 1 : 0
    border.color: Theme.highlight
    clip: true

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: root.popup ? 1 : 0
        }
        width: 3
        color: NotificationCenter.urgencyColor(root.notification)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: event => {
            if (event.button === Qt.LeftButton)
                NotificationCenter.activate(root.notification);
            else
                root.notification.dismiss();
        }
    }

    Image {
        id: icon
        anchors {
            left: parent.left
            top: parent.top
            leftMargin: 14
            topMargin: 10
        }
        width: visible ? 36 : 0
        height: 36
        visible: root.image !== "" && status === Image.Ready
        source: root.image
        sourceSize.width: 72
        sourceSize.height: 72
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Column {
        id: content
        anchors {
            left: icon.visible ? icon.right : parent.left
            right: parent.right
            top: parent.top
            leftMargin: 14 - (icon.visible ? 4 : 0)
            rightMargin: 10
            topMargin: 10
        }
        spacing: 3

        Item {
            width: parent.width
            height: appName.implicitHeight

            Text {
                id: appName
                anchors {
                    left: parent.left
                    right: when.left
                    rightMargin: 8
                }
                text: root.notification.appName || "notification"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                color: Theme.muted
            }

            Text {
                id: when
                anchors {
                    right: closeGlyph.left
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                text: NotificationCenter.ago(root.notification)
                font.family: Theme.fontFamily
                font.pointSize: Theme.smallSize
                color: Theme.muted
            }

            Text {
                id: closeGlyph
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: String.fromCodePoint(0xf0156)
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: close.containsMouse ? Theme.alert : Theme.muted
                opacity: root.hovered ? 1 : 0

                MouseArea {
                    id: close
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.notification.dismiss()
                }
            }
        }

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
            maximumLineCount: root.popup ? 4 : 2
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.text
        }

        Item {
            width: 1
            height: 3
            visible: root.buttons.length > 0
        }

        Flow {
            width: parent.width
            visible: root.buttons.length > 0
            spacing: 6

            Repeater {
                model: root.buttons

                Rectangle {
                    id: button
                    required property NotificationAction modelData

                    implicitWidth: buttonLabel.implicitWidth + 16
                    implicitHeight: 22
                    radius: Theme.roundingSmall
                    color: buttonMouse.containsMouse ? Theme.highlight : Theme.base

                    Text {
                        id: buttonLabel
                        anchors.centerIn: parent
                        text: button.modelData.text
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.smallSize
                        color: Theme.brightText
                    }

                    MouseArea {
                        id: buttonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            NotificationCenter.hide(root.notification);
                            button.modelData.invoke();
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: root.notification.expireTimeout > 0 ? root.notification.expireTimeout : 5000
        running: root.popup && !root.hovered && root.notification.expireTimeout !== 0 && root.notification.urgency !== NotificationUrgency.Critical
        onTriggered: NotificationCenter.hide(root.notification)
    }
}
