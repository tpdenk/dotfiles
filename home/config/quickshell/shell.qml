import Quickshell
import Quickshell.Io
import qs.bar
import qs.launcher

ShellRoot {
    Bar {}
    Launcher {}

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
