import Quickshell
import Quickshell.Io
import qs.bar
import qs.launcher
import qs.network
import qs.notifications

ShellRoot {
    Bar {}
    Launcher {}
    Network {}
    Notifications {}

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
