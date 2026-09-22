import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

Scope {
    id: root

    SidePanel {
        visible: UpdatesStatus.expanded
        layerNamespace: "updates"
        centered: true

        card: Component {
            UpdatesPanel {}
        }
    }

    IpcHandler {
        target: "updates"

        function toggle(): void {
            Panels.toggle("updates");
        }
        function open(): void {
            Panels.show("updates");
        }
        function close(): void {
            Panels.close("updates");
        }
        function refresh(): void {
            UpdatesStatus.refresh();
            FirmwareStatus.refresh();
        }
    }
}
