pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool open: false
    property string armed: ""
    property int current: 0

    readonly property var actions: [
        {
            id: "lock",
            label: "lock",
            key: "l",
            glyph: 0xf033e,
            confirm: false,
            command: ["loginctl", "lock-session"]
        },
        {
            id: "suspend",
            label: "suspend",
            key: "s",
            glyph: 0xf04b2,
            confirm: false,
            command: ["systemctl", "suspend"]
        },
        {
            id: "logout",
            label: "log out",
            key: "e",
            glyph: 0xf0343,
            confirm: false,
            command: ["uwsm", "stop"]
        },
        {
            id: "reboot",
            label: "reboot",
            key: "r",
            glyph: 0xf0709,
            confirm: true,
            command: ["systemctl", "reboot"]
        },
        {
            id: "shutdown",
            label: "shut down",
            key: "p",
            glyph: 0xf0425,
            confirm: true,
            command: ["systemctl", "poweroff"]
        }
    ]

    function show(action: string): void {
        const index = root.actions.findIndex(a => a.id === action);
        root.current = Math.max(0, index);
        root.armed = index >= 0 && root.actions[index].confirm ? action : "";
        root.open = true;
    }

    function hide(): void {
        root.open = false;
        root.armed = "";
    }

    function trigger(id: string): void {
        const action = root.actions.find(a => a.id === id);
        if (!action)
            return;
        root.current = root.actions.indexOf(action);
        if (action.confirm && root.armed !== id) {
            root.armed = id;
            return;
        }
        root.hide();
        Quickshell.execDetached(action.command);
    }
}
