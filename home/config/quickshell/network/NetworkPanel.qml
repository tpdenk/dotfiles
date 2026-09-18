import QtQuick
import qs

// The network details card: title, on/off toggle and live connection stats.
Rectangle {
    id: root

    // `label    value` line, value right aligned and elided
    component Stat: Item {
        id: stat
        required property string label
        required property string value

        implicitHeight: valueText.implicitHeight

        Text {
            id: labelText
            anchors.left: parent.left
            text: stat.label
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
            text: stat.value
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.text
        }
    }

    implicitWidth: 320
    implicitHeight: content.implicitHeight + 24
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
            margins: 12
        }
        spacing: 6

        Item {
            width: parent.width
            implicitHeight: Math.max(title.implicitHeight, toggle.implicitHeight)

            Text {
                id: title
                anchors.verticalCenter: parent.verticalCenter
                text: "Network"
                font.family: Theme.fontFamily
                font.pointSize: Theme.h2Size
                color: Theme.brightText
            }

            Toggle {
                id: toggle
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                checked: NetworkStatus.enabled
                onToggled: on => NetworkStatus.setEnabled(on)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.muted, 0.5)
        }

        // one tab per interface; pointless with a single one
        InterfaceTabs {
            width: parent.width
            visible: NetworkStatus.devices.length > 1
        }

        Rectangle {
            width: parent.width
            height: 1
            visible: NetworkStatus.devices.length > 1
            color: Qt.alpha(Theme.muted, 0.5)
        }

        // the wired equivalent would just repeat the tab's interface name
        Stat {
            width: parent.width
            visible: NetworkStatus.wifi
            label: "SSID"
            value: NetworkStatus.name || "—"
        }

        Stat {
            width: parent.width
            label: NetworkStatus.wifi ? "Signal" : "Link speed"
            value: NetworkStatus.wifi ? NetworkStatus.connected ? `${Math.round(NetworkStatus.signalStrength * 100)}%` : "—" : NetworkStatus.linkSpeed ? `${NetworkStatus.linkSpeed} Mbit/s` : "—"
        }

        Stat {
            width: parent.width
            label: "Ping"
            value: NetworkStatus.pingMs < 0 ? "—" : `${NetworkStatus.pingMs.toFixed(1)} ms`
        }

        Stat {
            width: parent.width
            label: "Packet loss"
            value: NetworkStatus.packetLoss < 0 ? "—" : `${Math.round(NetworkStatus.packetLoss)}%`
        }

        Stat {
            width: parent.width
            label: "Download"
            value: NetworkStatus.formatRate(NetworkStatus.rxRate)
        }

        Stat {
            width: parent.width
            label: "Upload"
            value: NetworkStatus.formatRate(NetworkStatus.txRate)
        }

        Stat {
            width: parent.width
            label: "IP address"
            value: NetworkStatus.address || "—"
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.muted, 0.5)
        }

        Stat {
            width: parent.width
            label: "Status"
            // connectivity is NetworkManager-wide, so it says nothing about an
            // interface that is down
            value: NetworkStatus.connected ? `${NetworkStatus.status} · ${NetworkStatus.connectivity}` : NetworkStatus.status
        }

        Item {
            width: parent.width
            implicitHeight: qualityLabel.implicitHeight

            Text {
                id: qualityLabel
                anchors.left: parent.left
                text: "Quality"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.muted
            }

            Row {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: NetworkStatus.qualityLabel
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.fontSize
                    color: Theme.text
                }

                SignalBars {
                    anchors.verticalCenter: parent.verticalCenter
                    level: NetworkStatus.quality
                }
            }
        }
    }
}
