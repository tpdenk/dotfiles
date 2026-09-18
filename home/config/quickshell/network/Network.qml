import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Network details, shown under the bar's NetworkIndicator.
Scope {
    id: root

    PanelWindow { // qmllint disable uncreatable-type
        visible: NetworkStatus.expanded

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "network"
        // never takes the keyboard: the panel can stay open while you type in
        // another window
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // below the bar, aligned with the indicator that opens it
        anchors {
            top: true
            right: true
        }
        margins {
            top: 38
            right: 8
        }

        implicitWidth: panel.implicitWidth
        implicitHeight: panel.implicitHeight
        color: "transparent"

        NetworkPanel {
            id: panel
            anchors.fill: parent
        }
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            NetworkStatus.expanded = !NetworkStatus.expanded;
        }
        function open(): void {
            NetworkStatus.expanded = true;
        }
        function close(): void {
            NetworkStatus.expanded = false;
        }
    }
}
