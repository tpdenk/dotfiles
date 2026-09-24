pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import QtQuick
import qs
import qs.widgets

Scope {
    id: root

    readonly property int maxToasts: 3

    PanelWindow { // qmllint disable uncreatable-type
        visible: NotificationCenter.popups.length > 0 && Panels.open !== "notifications"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notifications"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }
        margins {
            top: 38
            right: 8
        }
        implicitWidth: 360
        implicitHeight: stack.implicitHeight
        color: "transparent"

        Column {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                model: ScriptModel {
                    values: NotificationCenter.popups.slice(-root.maxToasts).reverse()
                }

                Toast {
                    required property Notification modelData
                    notification: modelData
                    popup: true
                    width: parent.width
                }
            }

            Pill {
                anchors.right: parent.right
                visible: NotificationCenter.popups.length > root.maxToasts
                label: `+${NotificationCenter.popups.length - root.maxToasts} more`
                labelColor: Theme.text
                onClicked: Panels.toggle("notifications")
            }
        }
    }

    Dropdown {
        name: "notifications"
        card: NotificationsPanel {}
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): void {
            NotificationCenter.dnd = !NotificationCenter.dnd;
        }
        function clear(): void {
            NotificationCenter.clear();
        }
    }
}
