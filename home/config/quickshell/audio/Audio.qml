import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// Audio details, shown under the bar's AudioIndicator.
Scope {
    id: root

    SidePanel {
        visible: AudioStatus.expanded
        layerNamespace: "audio"

        card: Component {
            AudioPanel {}
        }
    }

    IpcHandler {
        target: "audio"

        function toggle(): void {
            Panels.toggle("audio");
        }
        function open(): void {
            Panels.show("audio");
        }
        function close(): void {
            Panels.close("audio");
        }
    }
}
