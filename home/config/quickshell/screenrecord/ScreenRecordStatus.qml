pragma Singleton
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// One gpu-screen-recorder capture, owned by the shell: the bar pill lives
// exactly as long as the process does, so no state can be stale. A capture
// therefore ends with the shell; `qs ipc call shell reload` included.
//
// Asking for a capture opens `share-picker`, the same picker the screencast
// portal opens: a window records as the fixed region of the screen it sits
// on, a monitor records whole.
Singleton {
    id: root

    readonly property string directory: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.MoviesLocation)).replace(/^file:\/\//, "")) + "/Screenrecordings"

    // the breather between picking a target and the encoder starting: long
    // enough to put the window in front and take the pointer off it
    readonly property int countdownFrom: 3
    // seconds left of that, 0 once the encoder has the screen
    property int countdown: 0
    readonly property bool counting: countdown > 0

    readonly property bool recording: recorder.running
    readonly property bool active: counting || recording

    // what the picker settled on: gpu-screen-recorder's capture arguments,
    // either a monitor name or a region in layout coordinates, and the rate to
    // capture it at
    property var capture: []
    property int fps: 60
    // the same pick as {output, x, y, w, h} in that output's own coordinates,
    // which is what the outline around the capture is drawn from
    property var area: null

    // the file being written, "" while idle
    property string path: ""
    // wall clock rather than a tick count: a stalled or busy shell would
    // otherwise report less than has actually been recorded
    property double startedAt: 0
    property int elapsed: 0

    readonly property string icon: String.fromCodePoint(0xf044a) // record

    // the pill's text: the countdown while it runs, then m:ss, then h:mm:ss
    readonly property string label: {
        if (root.counting)
            return String(root.countdown);
        const s = root.elapsed % 60;
        const m = Math.floor(root.elapsed / 60) % 60;
        const h = Math.floor(root.elapsed / 3600);
        const pad = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
    }

    function start(): void {
        if (root.active || picker.running)
            return;
        picker.running = true;
    }

    // SIGINT is the only signal gpu-screen-recorder saves the file on: SIGTERM,
    // which `running = false` would send, leaves the container without its
    // index and unplayable
    function stop(): void {
        if (root.counting)
            root.countdown = 0;
        else if (recorder.running)
            recorder.signal(2);
    }

    // the file name is settled here rather than at `start`, so it stamps when
    // the recording began and not when the picker opened
    function ignite(): void {
        if (root.capture.length === 0)
            return;

        root.path = `${root.directory}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.mp4`;
        root.startedAt = Date.now();
        root.elapsed = 0;

        recorder.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "screenrecord", root.directory, "gpu-screen-recorder"].concat(root.capture, ["-f", String(root.fps), "-fm", "cfr", "-o", root.path]);
        recorder.running = true;
    }

    function notify(summary: string, body: string, transient: bool): void {
        Quickshell.execDetached(["notify-send", "-a", "screenrecord"].concat(transient ? ["-e"] : [], ["-i", "media-record", summary, body]));
    }

    Process {
        id: picker

        command: [`${Quickshell.env("HOME")}/.local/bin/share-picker`, "--area"]

        stdout: StdioCollector {
            id: pick
        }

        // a cancelled selection (Esc, or a click without a box under it) exits
        // non-zero and is not worth a notification
        onExited: code => {
            if (code !== 0)
                return;

            const [kind, output, x, y, w, h] = pick.text.trim().split(" ");
            root.arm(kind, output, x, y, w, h);
        }
    }

    // share-picker's pick fields, in layout coordinates
    function arm(kind: string, output: string, x: string, y: string, w: string, h: string): void {
        if (root.active || !kind || !output)
            return;

        // a window records as the region it occupies: gpu-screen-recorder
        // works out which monitor that lands on
        root.capture = kind === "screen" ? ["-w", output] : ["-w", "region", "-region", `${w}x${h}+${x}+${y}`];
        // capping at 60 keeps a 120 Hz panel from doubling the file size
        // for frames nothing will play back
        const host = Hyprland.monitors.values.find(candidate => candidate.name === output);
        const ipc = host?.lastIpcObject ?? null;
        root.fps = Math.min(60, Math.round(ipc?.refreshRate ?? 60));
        // the capture is a fixed box even when a window was picked, so the
        // outline is the box and does not follow the window
        root.area = {
            output: output,
            x: Number(x) - (ipc?.x ?? 0),
            y: Number(y) - (ipc?.y ?? 0),
            w: Number(w),
            h: Number(h)
        };

        root.countdown = root.countdownFrom;
    }

    Process {
        id: recorder

        // the encoder prints its chosen device and codec here too, so only a
        // failure gets to show it
        stderr: StdioCollector {
            id: errors
        }

        onExited: code => {
            if (code === 0)
                root.notify("Screen recording saved", root.path.replace(Quickshell.env("HOME"), "~"), true);
            else
                root.notify("Screen recording failed", errors.text.trim().split("\n").pop() || `gpu-screen-recorder exited with ${code}`, false);
            root.path = "";
            root.capture = [];
            root.area = null;
        }
    }

    Timer {
        interval: 1000
        running: root.counting
        repeat: true

        onTriggered: {
            root.countdown -= 1;
            if (root.countdown === 0)
                root.ignite();
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }
}
