pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs

// One gpu-screen-recorder capture, owned by the shell: the bar pill lives
// exactly as long as the process does, so no state can be stale. A capture
// therefore ends with the shell; `qs ipc call shell reload` included.
//
// Asking for a capture opens a slurp picker over every window and every
// monitor, the way hyprshot picks a screenshot: a window records as a fixed
// region of the screen it sits on, a monitor records whole.
Singleton {
    id: root

    readonly property string directory: Quickshell.env("HOME") + "/Videos/Screenrecordings"

    // the breather between picking a target and the encoder starting: long
    // enough to put the window in front and take the pointer off it
    readonly property int countdownFrom: 3
    // seconds left of that, 0 once the encoder has the screen
    property int countdown: 0
    readonly property bool counting: countdown > 0

    readonly property bool recording: recorder.running
    readonly property bool active: counting || recording

    // what the picker settled on: gpu-screen-recorder's `-w`, either a monitor
    // name or a `WxH+X+Y` region in compositor coordinates, and the rate to
    // capture it at
    property string source: ""
    property int fps: 60

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
        picker.command = pickerCommand();
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
        if (root.source === "")
            return;

        root.path = `${root.directory}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.mp4`;
        root.startedAt = Date.now();
        root.elapsed = 0;

        // the region form of `-w` takes compositor coordinates, the same ones
        // slurp reports, and encodes at the monitor's real pixel size; cfr
        // rather than the default variable framerate, as these files get
        // handed to players and editors that stutter on a vfr mp4.
        // The directory is made here rather than at link time: a fresh install
        // has no ~/Videos, and the encoder will not create the file's parent.
        recorder.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "screenrecord", root.directory, "gpu-screen-recorder", "-w", root.source, "-f", String(root.fps), "-fm", "cfr", "-o", root.path];
        recorder.running = true;
    }

    // every mapped window of the visible workspaces, plus (via slurp's -o)
    // every monitor. slurp picks the smallest box under the pointer, so a
    // click inside a window takes the window and one on bare desktop takes the
    // monitor. The label is how the pick is identified afterwards: a window
    // address, or an output name.
    function pickerCommand(): var {
        const boxes = Hyprland.toplevels.values.filter(toplevel => {
            const client = toplevel.lastIpcObject;
            return client && client.mapped && !client.hidden && toplevel.workspace?.active;
        }).map(toplevel => {
            const client = toplevel.lastIpcObject;
            return `${client.at[0]},${client.at[1]} ${client.size[0]}x${client.size[1]} ${toplevel.address}`;
        }).join("\n");

        const rgba = (color, alpha) => color.toString().slice(1) + alpha;
        return ["sh", "-c", 'printf %s "$1" | slurp -r -o -f "%wx%h+%x+%y %l" -b "$2" -c "$3" -s "$4"', "screenrecord", boxes, rgba(Theme.background, "99"), rgba(Theme.accent, "ff"), rgba(Theme.accent, "26")];
    }

    function notify(summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "screenrecord", "-e", "-i", "media-record", summary, body]);
    }

    Process {
        id: picker

        stdout: StdioCollector {
            id: pick
        }

        // a cancelled selection (Esc, or a click without a box under it) exits
        // non-zero and is not worth a notification
        onExited: code => {
            if (code !== 0)
                return;

            const parts = pick.text.trim().split(" ");
            const label = parts.slice(1).join(" ");
            const monitor = Hyprland.monitors.values.find(candidate => candidate.name === label);
            const toplevel = monitor ? null : Hyprland.toplevels.values.find(candidate => candidate.address === label);

            // a window records as the region it occupies: gpu-screen-recorder
            // works out which monitor that lands on
            root.source = monitor ? monitor.name : parts[0];
            // capping at 60 keeps a 120 Hz panel from doubling the file size
            // for frames nothing will play back
            root.fps = Math.min(60, Math.round((monitor ?? toplevel?.monitor)?.lastIpcObject?.refreshRate ?? 60));

            root.countdown = root.countdownFrom;
        }
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
                root.notify("Screen recording saved", root.path.replace(Quickshell.env("HOME"), "~"));
            else
                root.notify("Screen recording failed", errors.text.trim().split("\n").pop() || `gpu-screen-recorder exited with ${code}`);
            root.path = "";
            root.source = "";
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
