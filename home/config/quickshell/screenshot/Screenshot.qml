import Quickshell
import Quickshell.Io

// The screenshot's keybind surface; the capture itself is ScreenshotStatus.
Scope {
    IpcHandler {
        target: "screenshot"

        function take(): void {
            ScreenshotStatus.take();
        }
    }
}
