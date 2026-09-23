import QtQuick
import qs
import qs.widgets

// The tailscale card: title, on/off toggle for this node, its place on the
// tailnet, and the peers it can see.
PanelCard {
    title: "Tailscale"

    LabeledRow {
        width: parent.width
        label: TailscaleStatus.hostName || "This device"

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            enabled: TailscaleStatus.toggleable
            checked: TailscaleStatus.running
            onToggled: on => TailscaleStatus.setEnabled(on)
        }
    }

    Divider {
        width: parent.width
    }

    Stat {
        width: parent.width
        label: "Status"
        value: TailscaleStatus.status
    }

    Stat {
        width: parent.width
        visible: TailscaleStatus.tailnet !== ""
        label: "Tailnet"
        value: TailscaleStatus.tailnet
    }

    CopyStat {
        width: parent.width
        visible: TailscaleStatus.running && TailscaleStatus.address !== ""
        label: "Address"
        value: TailscaleStatus.address
    }

    CopyStat {
        width: parent.width
        visible: TailscaleStatus.running && TailscaleStatus.dnsName !== ""
        label: "DNS name"
        value: TailscaleStatus.dnsName
    }

    Stat {
        width: parent.width
        visible: TailscaleStatus.running
        label: "Online"
        value: `${TailscaleStatus.online}/${TailscaleStatus.peers.length}`
    }

    Stat {
        width: parent.width
        visible: TailscaleStatus.exitNode !== ""
        label: "Exit node"
        value: TailscaleStatus.exitNode
    }

    Divider {
        width: parent.width
    }

    TailscalePeers {
        width: parent.width
    }
}
