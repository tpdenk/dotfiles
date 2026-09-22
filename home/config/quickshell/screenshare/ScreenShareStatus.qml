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
    // what the picker last handed the portal: {type, output, x, y, w, h,
    // address} in that output's own coordinates, or null when the share did
    // not come from the picker and its area is anyone's guess
    property var area: null

    FileView {
        id: areaFile
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/share-picker.area`
        blockLoading: true
        printErrors: false
    }

    function pickedArea(): var {
        areaFile.reload();
        const parts = String(areaFile.text()).trim().split(" ");
        if (parts.length < 8)
            return null;

        const [stamp, type, output, x, y, w, h, address] = parts;
        // a pick this old belongs to an earlier share, not this one
        if (Date.now() / 1000 - Number(stamp) > 30)
            return null;

        return {
            type: type,
            output: output,
            x: Number(x),
            y: Number(y),
            w: Number(w),
            h: Number(h),
            address: address === "-" ? "" : address
        };
    }

    Connections {
        target: Hyprland

        // a region capture ends and reopens its session every frame, so the
        // share is over only once an "off" is left standing
        function onRawEvent(event): void {
            if (event.name !== "screencast")
                return;

            const [state, owner] = String(event.data).split(",");
            if (state !== "1") {
                ending.restart();
                return;
            }

            ending.stop();
            if (root.active)
                return;

            root.owner = owner ?? "";
            root.area = root.pickedArea();
            root.active = true;
        }
    }

    Timer {
        id: ending
        interval: 1000

        onTriggered: {
            root.active = false;
            root.owner = "";
            root.area = null;
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
