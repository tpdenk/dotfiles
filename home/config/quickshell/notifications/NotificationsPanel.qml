pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs
import qs.widgets

PanelCard {
    title: "Notifications"
    subtitle: NotificationCenter.count > 0 ? String(NotificationCenter.count) : ""

    LabeledRow {
        width: parent.width
        label: "Do not disturb"

        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            checked: NotificationCenter.dnd
            onToggled: on => NotificationCenter.dnd = on
        }
    }

    Divider {
        width: parent.width
    }

    SelectList {
        width: parent.width
        placeholder: "Nothing new"
        maxHeight: 460
        model: ScriptModel {
            values: NotificationCenter.history
        }
        delegate: Toast {
            required property Notification modelData
            notification: modelData
            width: ListView.view.width
        }
    }

    Item {
        width: parent.width
        height: clearAll.implicitHeight
        visible: NotificationCenter.count > 0

        Pill {
            id: clearAll
            anchors.right: parent.right
            label: "clear all"
            labelColor: Theme.text
            onClicked: {
                NotificationCenter.clear();
                Panels.close("notifications");
            }
        }
    }
}
