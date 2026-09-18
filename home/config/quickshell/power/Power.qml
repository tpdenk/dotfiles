import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// Power actions, shown under the bar's PowerIndicator.
Scope {
    id: root

    SidePanel {
        visible: PowerStatus.expanded
        layerNamespace: "power"

        card: Component {
            PowerPanel {}
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            Panels.toggle("power");
        }
        function open(): void {
            Panels.show("power");
        }
        function close(): void {
            Panels.close("power");
        }
    }
}
