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

    // wide enough for a full IPv6 address with prefix on one line
    implicitWidth: 400
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

        Text {
            text: "Network"
            font.family: Theme.fontFamily
            font.pointSize: Theme.h2Size
            color: Theme.brightText
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

        // the switch belongs to the selected interface, not to networking as a
        // whole, so it lives inside the tab's own content
        Item {
            width: parent.width
            implicitHeight: Math.max(interfaceName.implicitHeight, toggle.implicitHeight)

            Text {
                id: interfaceName
                anchors.verticalCenter: parent.verticalCenter
                text: NetworkStatus.device?.name ?? "No interface"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.muted
            }

            Toggle {
                id: toggle
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                enabled: !!NetworkStatus.device
                checked: NetworkStatus.enabled
                onToggled: on => NetworkStatus.setEnabled(NetworkStatus.device, on)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.muted, 0.5)
        }

        // what this interface is attached to
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
            visible: NetworkStatus.wifi
            label: "Security"
            value: NetworkStatus.connected ? NetworkStatus.isOpen(NetworkStatus.network) ? "Open" : NetworkStatus.security : "—"
        }

        Stat {
            width: parent.width
            visible: NetworkStatus.wifi && NetworkStatus.wifiMode !== ""
            label: "Mode"
            value: NetworkStatus.wifiMode
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.muted, 0.5)
        }

        // addressing
        Stat {
            width: parent.width
            label: "IPv4"
            value: NetworkStatus.address || "—"
        }

        Stat {
            width: parent.width
            label: "Subnet"
            value: NetworkStatus.subnet || "—"
        }

        Column {
            width: parent.width
            visible: NetworkStatus.ipv6.length > 0

            Text {
                text: "IPv6"
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.muted
            }

            Repeater {
                model: NetworkStatus.ipv6

                // a full address with prefix is wider than a label/value row
                // allows, so each gets its own line, aligned with the values
                // above it
                Text {
                    required property string modelData

                    width: parent.width
                    text: modelData
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WrapAnywhere
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    color: Theme.text
                }
            }
        }

        Stat {
            width: parent.width
            label: "Gateway"
            value: NetworkStatus.gateway || "—"
        }

        // which NIC a packet leaves by is a routing decision, not an address
        // one: same-prefix interfaces are ranked by metric
        Stat {
            width: parent.width
            label: "Route"
            value: NetworkStatus.routeMetric < 0 ? "—" : `${NetworkStatus.routed ? "active" : "standby"} · metric ${NetworkStatus.routeMetric}`
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.muted, 0.5)
        }

        // live traffic, measured only while this tab is on screen
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

        Rectangle {
            width: parent.width
            height: 1
            visible: NetworkStatus.wifi
            color: Qt.alpha(Theme.muted, 0.5)
        }

        WifiNetworks {
            width: parent.width
            visible: NetworkStatus.wifi
        }
    }
}
