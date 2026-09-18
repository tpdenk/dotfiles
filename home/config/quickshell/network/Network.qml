import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// Network details, shown under the bar's NetworkIndicator.
Scope {
    id: root

    SidePanel {
        visible: NetworkStatus.expanded
        layerNamespace: "network"
        // only while a wifi passphrase is being entered
        grabKeyboard: !!NetworkStatus.pendingNetwork

        card: Component {
            NetworkPanel {}
        }
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            Panels.toggle("network");
        }
        function open(): void {
            Panels.show("network");
        }
        function close(): void {
            Panels.close("network");
        }
    }
}
