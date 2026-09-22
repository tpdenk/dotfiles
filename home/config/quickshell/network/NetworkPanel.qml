import QtQuick
import qs
import qs.widgets

// The network details card: title, on/off toggle and live connection stats.
PanelCard {
    title: "Network"

    // one tab per interface; pointless with a single one
    InterfaceTabs {
        width: parent.width
        visible: NetworkStatus.devices.length > 1
    }

    // the switch belongs to the selected interface, not to networking as a
    // whole, so it lives inside the tab's own content
    LabeledRow {
        width: parent.width
        label: NetworkStatus.device?.name ?? "No interface"

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            enabled: !!NetworkStatus.device
            checked: NetworkStatus.enabled
            onToggled: on => NetworkStatus.setEnabled(NetworkStatus.device, on)
        }
    }

    Divider {
        width: parent.width
    }

    Stat {
        width: parent.width
        label: "Status"
        // connectivity is NetworkManager-wide, so it says nothing about an
        // interface that is down
        value: NetworkStatus.connected ? `${NetworkStatus.status} · ${NetworkStatus.connectivity}` : NetworkStatus.status
    }

    LabeledRow {
        width: parent.width
        label: "Quality"

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

    Divider {
        width: parent.width
    }

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

    Divider {
        width: parent.width
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

    Divider {
        width: parent.width
        visible: NetworkStatus.wifi
    }

    WifiNetworks {
        width: parent.width
        visible: NetworkStatus.wifi
    }
}
