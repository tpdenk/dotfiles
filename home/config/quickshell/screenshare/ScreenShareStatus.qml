pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.screenrecord
import qs.screenshot

// Something other than the shell has the screen: in practice a screencast the
// portal handed out, to a meeting in a browser. The portal's picker is
// share-picker, which leaves every pick in a file, and the outline around the
// share is drawn from that.
Singleton {
    id: root

    property bool active: false
    // the pick behind the share, {type, output, x, y, w, h, address} in that
    // output's own coordinates, or null when no pick is young enough to be it
    property var area: null

    // the pick lands in the file before the portal starts capturing, and a
    // meeting that switches to another window or screen picks again while its
    // capture never goes off. So the file is what is followed, not the capture
    // starting: a fresh pick during a share is that share's new area.
    FileView {
        id: picks
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/share-picker.area`
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: {
            const pick = root.pickedArea();
            if (root.active && pick)
                root.area = pick;
        }
    }

    // the newest pick, or null when there is none young enough to be this
    // share's. reload() alone leaves text() one load behind; the job has to be
    // waited out for the read to be what is on disk now.
    function pickedArea(): var {
        picks.reload();
        picks.waitForJob();
        const parts = String(picks.text()).trim().split(" ");
        if (parts.length < 8)
            return null;

        const [stamp, type, output, x, y, w, h, address] = parts;
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

            // a screenshot and a recording are captures too, and the shell
            // starts both: it says so itself rather than through this, which
            // only speaks for captures nothing here asked for
            if (ScreenRecordStatus.active || ScreenshotStatus.active)
                return;

            const state = String(event.data).split(",")[0];
            if (state !== "1") {
                ending.restart();
                return;
            }

            ending.stop();
            if (root.active)
                return;

            root.area = root.pickedArea();
            root.active = true;
        }
    }

    Timer {
        id: ending
        interval: 1000

        onTriggered: {
            root.active = false;
            root.area = null;
        }
    }

    // a share already running when the shell starts has no event left to catch
    Process {
        running: true
        command: ["sh", "-c", `pw-dump | jq -e 'any(.[]?; (.info?.props?."node.name" // "") == "xdg-desktop-portal-hyprland" and (.info?.props?."media.class" // "") == "Video/Source")' >/dev/null`]

        onExited: code => {
            if (code === 0) {
                root.area = root.pickedArea();
                root.active = true;
            }
        }
    }
}
