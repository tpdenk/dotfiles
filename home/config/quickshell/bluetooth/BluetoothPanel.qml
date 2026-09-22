import QtQuick
import qs
import qs.widgets

// The bluetooth card: title, controller on/off toggle, what the controller is
// currently advertising, and the devices around it.
PanelCard {
    title: "Bluetooth"

    LabeledRow {
        width: parent.width
        label: BluetoothStatus.adapterName || "No adapter"

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            enabled: BluetoothStatus.present
            checked: BluetoothStatus.enabled
            onToggled: on => BluetoothStatus.setEnabled(on)
        }
    }

    Divider {
        width: parent.width
    }

    // being visible to strangers is a state worth announcing, so it is said in
    // words and in the accent colour rather than left to the stat below
    Text {
        width: parent.width
        visible: BluetoothStatus.enabled
        text: BluetoothStatus.discoverable ? `Visible as “${BluetoothStatus.adapterName}” while this panel is open` : "Making this device visible…"
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.accent
    }

    Divider {
        width: parent.width
    }

    Stat {
        width: parent.width
        label: "Status"
        value: BluetoothStatus.status
    }

    Stat {
        width: parent.width
        label: "Connected"
        value: `${BluetoothStatus.connectedCount || "—"}`
    }

    Stat {
        width: parent.width
        label: "Visibility"
        value: BluetoothStatus.discoverable ? "Discoverable" : "Hidden"
    }

    Stat {
        width: parent.width
        label: "Scan"
        value: BluetoothStatus.scanning ? "Scanning" : "Idle"
    }

    Divider {
        width: parent.width
    }

    BluetoothDevices {
        width: parent.width
    }
}
