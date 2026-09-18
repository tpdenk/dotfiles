pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs

// Access points seen by the selected wifi interface. Click one to join; a
// secured network we hold no secrets for asks for its passphrase inline.
Column {
    id: root

    spacing: 6

    Text {
        text: NetworkStatus.radioEnabled ? "Networks" : "Wi-Fi radio off"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.muted
    }

    ListView {
        id: list
        width: parent.width
        // a handful of rows, then scroll: the panel must not grow unbounded
        height: Math.min(contentHeight, 132)
        visible: NetworkStatus.radioEnabled && count > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        model: ScriptModel {
            values: NetworkStatus.wifiNetworks
        }

        delegate: Rectangle {
            id: row
            required property var modelData

            width: list.width
            height: 24
            radius: Theme.roundingSmall
            color: hover.containsMouse ? Qt.alpha(Theme.accent, 0.15) : "transparent"

            Text {
                anchors {
                    left: parent.left
                    leftMargin: 6
                    right: meta.left
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: row.modelData.name
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: row.modelData.connected ? Theme.accent : row.modelData.known ? Theme.brightText : Theme.text
            }

            Row {
                id: meta
                anchors {
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkStatus.isOpen(row.modelData) ? "open" : NetworkStatus.securityOf(row.modelData)
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    color: Theme.muted
                }

                SignalBars {
                    anchors.verticalCenter: parent.verticalCenter
                    level: Math.max(1, Math.ceil(row.modelData.signalStrength * 4))
                }
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: NetworkStatus.join(row.modelData)
            }
        }
    }

    Text {
        width: parent.width
        visible: NetworkStatus.radioEnabled && list.count === 0
        text: "Scanning…"
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
        color: Theme.muted
    }

    // passphrase entry; the panel takes keyboard focus only while this is up
    Column {
        width: parent.width
        spacing: 4
        visible: !!NetworkStatus.pendingNetwork

        Text {
            width: parent.width
            text: `Passphrase for ${NetworkStatus.pendingNetwork?.name ?? ""}`
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }

        Rectangle {
            width: parent.width
            implicitHeight: input.implicitHeight + 10
            radius: Theme.roundingSmall
            color: Qt.alpha(Theme.muted, 0.2)
            border.width: Theme.borderSize
            border.color: Theme.accent

            TextInput {
                id: input
                anchors {
                    fill: parent
                    margins: 5
                }
                echoMode: TextInput.Password
                passwordCharacter: "•"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.brightText

                onAccepted: NetworkStatus.submitPassword(text)
                Keys.onEscapePressed: NetworkStatus.cancelJoin()
            }
        }

        Text {
            width: parent.width
            text: "Enter to join · Esc to cancel"
            font.family: Theme.fontFamily
            font.pointSize: Theme.smallSize
            color: Theme.muted
        }
    }

    Text {
        width: parent.width
        visible: NetworkStatus.joinError !== ""
        text: NetworkStatus.joinError
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.accentSecondary
    }

    Connections {
        target: NetworkStatus

        function onPendingNetworkChanged(): void {
            if (!NetworkStatus.pendingNetwork)
                return;
            input.text = "";
            input.forceActiveFocus();
        }
    }
}
