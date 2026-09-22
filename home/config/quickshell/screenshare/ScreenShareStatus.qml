pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property bool active: false
    // what the client is capturing: "monitor" or "window"
    property string owner: ""

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name !== "screencast")
                return;

            const [state, owner] = String(event.data).split(",");
            root.active = state === "1";
            root.owner = owner ?? "";
        }
    }

    // a share already running when the shell starts has no event left to catch
    Process {
        running: true
        command: ["sh", "-c", `pw-dump | jq -e 'any(.[]?; (.info?.props?."node.name" // "") == "xdg-desktop-portal-hyprland" and (.info?.props?."media.class" // "") == "Video/Source")' >/dev/null`]

        onExited: code => {
            if (code === 0)
                root.active = true;
        }
    }
}
