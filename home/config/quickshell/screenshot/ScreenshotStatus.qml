pragma Singleton
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick

// One screenshot, owned by the shell the way a recording is: the bar knows a
// capture it started itself, so the share pill stays down for it.
//
// The pick runs through `share-picker`, the same picker the screencast portal
// and the recorder open. The screen is frozen for it, so a menu or a tooltip
// can be shot; grim then reads the freeze, which carries the same pixels.
Singleton {
    id: root

    readonly property string directory: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.PicturesLocation)).replace(/^file:\/\//, "")) + "/Screenshots"

    // from the moment the screen freezes until the file is on disk
    readonly property bool active: freeze.running || picker.running || capture.running

    property var last: null
    property var pending: null

    function dismiss(): void {
        root.last = null;
    }

    function discard(): void {
        if (!root.last)
            return;
        Quickshell.execDetached(["rm", "-f", "--", root.last.path]);
        root.last = null;
    }

    function take(): void {
        if (root.active)
            return;

        freeze.running = true;
        settle.restart();
    }

    function notify(summary: string, body: string, icon: string): void {
        Quickshell.execDetached(["notify-send", "-a", "screenshot", "-i", icon, summary, body]);
    }

    // hyprpicker needs the moment it takes to put the frozen screen up before
    // the picker draws on top of it
    Timer {
        id: settle
        interval: 200
        onTriggered: picker.running = true
    }

    Process {
        id: freeze
        command: ["hyprpicker", "-r", "-z"]
    }

    Process {
        id: picker

        command: [`${Quickshell.env("HOME")}/.local/bin/share-picker`, "--area"]

        stdout: StdioCollector {
            id: pick
        }

        // a cancelled pick (Esc, or a click without a box under it) exits
        // non-zero and is not worth a notification
        onExited: code => {
            const [kind, output, x, y, w, h] = pick.text.trim().split(" ");
            if (code !== 0 || !kind || !output) {
                freeze.running = false;
                return;
            }

            root.pending = {
                kind: kind,
                output: output,
                x: x,
                y: y,
                w: w,
                h: h
            };
            const path = `${root.directory}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.png`;
            // a whole monitor goes through -o: grim writes its exact pixels,
            // with no rounding of the layout box back into them
            const area = kind === "screen" ? ["-o", output] : ["-g", `${x},${y} ${w}x${h}`];

            capture.path = path;
            capture.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "screenshot", root.directory, "grim"].concat(area, [path]);
            capture.running = true;
        }
    }

    Process {
        id: capture

        property string path: ""

        stderr: StdioCollector {
            id: errors
        }

        onExited: code => {
            freeze.running = false;
            root.last = null;

            if (code === 0) {
                Quickshell.execDetached(["sh", "-c", 'exec wl-copy --type image/png <"$1"', "screenshot", capture.path]);
                root.last = Object.assign({
                    path: capture.path
                }, root.pending);
            } else
                root.notify("Screenshot failed", errors.text.trim().split("\n").pop() || `grim exited with ${code}`, "image-missing");

            capture.path = "";
            root.pending = null;
        }
    }
}
