import Quickshell
import Quickshell.Io
import qs.audio
import qs.bar
import qs.bluetooth
import qs.launcher
import qs.network
import qs.notifications
import qs.power

ShellRoot {
    Bar {}
    Audio {}
    Bluetooth {}
    Launcher {}
    Network {}
    Notifications {}
    Power {}

    IpcHandler {
        target: "shell"

        function reload(): void {
            Quickshell.reload(false);
        }
        function hardReload(): void {
            Quickshell.reload(true);
        }
    }
}
