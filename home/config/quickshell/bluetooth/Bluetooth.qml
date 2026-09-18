import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// Bluetooth details, shown under the bar's BluetoothIndicator.
Scope {
    id: root

    SidePanel {
        visible: BluetoothStatus.expanded
        layerNamespace: "bluetooth"

        card: Component {
            BluetoothPanel {}
        }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            Panels.toggle("bluetooth");
        }
        function open(): void {
            Panels.show("bluetooth");
        }
        function close(): void {
            Panels.close("bluetooth");
        }
    }
}
