import Quickshell
import Quickshell.Io
import qs.audio
import qs.bar
import qs.bluetooth
import qs.docker
import qs.launcher
import qs.network
import qs.notifications
import qs.power
import qs.screenrecord
import qs.screenshare
import qs.screenshot
import qs.updates

ShellRoot {
    Bar {}
    Audio {}
    Bluetooth {}
    Docker {}
    Launcher {}
    Network {}
    Notifications {}
    Power {}
    ScreenRecord {}
    ScreenShare {}
    Screenshot {}
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

    // `qs ipc call panels toggle <name>`, for the dropdowns' keybinds
    IpcHandler {
        target: "panels"

        function toggle(name: string): void {
            Panels.toggle(name);
        }
    }
}
