import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// The container list, shown under the bar's DockerIndicator.
Scope {
    id: root

    SidePanel {
        visible: DockerStatus.expanded
        layerNamespace: "docker"

        card: Component {
            DockerPanel {}
        }
    }

    IpcHandler {
        target: "docker"

        function toggle(): void {
            Panels.toggle("docker");
        }
        function open(): void {
            Panels.show("docker");
        }
        function close(): void {
            Panels.close("docker");
        }
        function refresh(): void {
            DockerStatus.refresh();
        }
    }
}
