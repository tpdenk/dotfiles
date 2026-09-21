import Quickshell
import Quickshell.Io

// The screen recorder's keybind surface; the capture itself is
// ScreenRecordStatus, which the bar pill watches.
Scope {
    IpcHandler {
        target: "screenrecord"

        function start(): void {
            ScreenRecordStatus.start();
        }
        function stop(): void {
            ScreenRecordStatus.stop();
        }
    }
}
