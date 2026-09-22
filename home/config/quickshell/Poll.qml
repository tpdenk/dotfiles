import Quickshell
import Quickshell.Io
import QtQuick

// Runs `command` every `interval` ms and whenever `refresh()` asks. A clean
// exit hands stdout to `finished`; a nonzero exit, or a binary that cannot be
// started at all, raises `failed`.
Scope {
    id: root

    required property list<string> command
    required property int interval

    signal finished(text: string)
    signal failed

    property bool pending: false

    function refresh(): void {
        root.pending = true;
        proc.running = true;
    }

    Process {
        id: proc
        command: root.command

        stdout: StdioCollector {
            id: stdout
        }

        onExited: code => {
            root.pending = false;
            if (code === 0)
                root.finished(stdout.text);
            else
                root.failed();
        }

        // a binary that cannot be started drops `running` without ever
        // reaching `exited`
        onRunningChanged: {
            if (running || !root.pending)
                return;
            root.pending = false;
            root.failed();
        }
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
