pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs

Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    property var arrived: ({})
    property double now: Date.now()

    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: server.trackedNotifications.values.length

    readonly property string icon: String.fromCodePoint(dnd ? 0xf009b : 0xf009a)

    function ephemeral(n: var): bool {
        return n.transient || n.urgency === NotificationUrgency.Low;
    }

    function hide(n: var): void {
        root.popups = root.popups.filter(p => p !== n);
        if (n && root.ephemeral(n))
            n.expire();
    }

    function clear(): void {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    function activate(n: var): void {
        const action = n.actions.find(a => a.identifier === "default");
        root.hide(n);
        if (action)
            action.invoke();
    }

    function urgencyColor(n: var): color {
        switch (n?.urgency) {
        case NotificationUrgency.Critical:
            return Theme.alert;
        case NotificationUrgency.Low:
            return Theme.muted;
        default:
            return Theme.accent;
        }
    }

    function ago(n: var): string {
        const at = root.arrived[n?.id] ?? root.now;
        const s = Math.max(0, Math.round((root.now - at) / 1000));
        if (s < 45)
            return "now";
        if (s < 3600)
            return `${Math.max(1, Math.round(s / 60))}m`;
        if (s < 86400)
            return `${Math.round(s / 3600)}h`;
        return Qt.formatDateTime(new Date(at), "ddd");
    }

    function imageOf(n: var): string {
        if (!n)
            return "";
        if (n.image !== "")
            return n.image;
        const icon = n.appIcon ?? "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.startsWith("file:"))
            return icon;
        return icon !== "" ? Quickshell.iconPath(icon, true) : "";
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        bodySupported: true

        onNotification: notification => {
            const sync = notification.hints["x-canonical-private-synchronous"];
            if (sync)
                for (const old of server.trackedNotifications.values)
                    if (old.hints["x-canonical-private-synchronous"] === sync)
                        old.dismiss();
            const popup = !root.dnd || notification.urgency === NotificationUrgency.Critical;
            if (!popup && root.ephemeral(notification))
                return;
            notification.tracked = true;

            root.now = Date.now();
            root.arrived[notification.id] = root.now;
            notification.closed.connect(() => {
                root.popups = root.popups.filter(p => p !== notification);
                delete root.arrived[notification.id];
            });

            if (popup)
                root.popups = root.popups.concat([notification]);
        }
    }
}
