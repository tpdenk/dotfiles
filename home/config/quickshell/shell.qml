import Quickshell
import Quickshell.Io
import qs.audio
import qs.bar
import qs.bluetooth
import qs.launcher
import qs.network
import qs.notifications
import qs.power
import qs.screenrecord
import qs.updates

ShellRoot {
    Bar {}
    Audio {}
    Bluetooth {}
    Launcher {}
    Network {}
    Notifications {}
    Power {}
    ScreenRecord {}
    Updates {}

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
