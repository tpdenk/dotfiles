pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import qs

Scope {
    id: root

    NotificationServer {
        id: server

        onNotification: notification => {
            const sync = notification.hints["x-canonical-private-synchronous"];
            if (sync)
                for (const old of server.trackedNotifications.values)
                    if (old.hints["x-canonical-private-synchronous"] === sync)
                        old.dismiss();
            notification.tracked = true;
        }
    }

    PanelWindow { // qmllint disable uncreatable-type
        visible: server.trackedNotifications.values.length > 0

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notifications"
        exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        margins.top: 38
        implicitWidth: 360
        implicitHeight: stack.implicitHeight
        color: "transparent"

        Column {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                Toast {
                    required property Notification modelData
                    notification: modelData
                    width: parent.width
                }
            }
        }
    }
}
