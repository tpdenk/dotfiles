pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs
import qs.widgets

// Access points seen by the selected wifi interface. Click one to join; a
// secured network we hold no secrets for asks for its passphrase inline.
Column {
    id: root

    spacing: 6

    SelectList {
        width: parent.width
        title: NetworkStatus.radioEnabled ? "Networks" : "Wi-Fi radio off"
        placeholder: NetworkStatus.radioEnabled ? "Scanning…" : ""

        model: ScriptModel {
            values: NetworkStatus.radioEnabled ? NetworkStatus.wifiNetworks : []
        }

        delegate: SelectRow {
            id: row
            required property var modelData

            width: ListView.view.width
            label: modelData.name
            labelColor: modelData.connected ? Theme.accent : modelData.known ? Theme.brightText : Theme.text
            onClicked: NetworkStatus.join(row.modelData)

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
