pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int interval: 5000

    property bool available: false
    property int count: 0

    readonly property string icon: String.fromCodePoint(0xf0868) // docker
    readonly property string label: String(count)

    property bool pending: false

    function refresh(): void {
        root.pending = true;
        proc.running = true;
    }

    function drop(): void {
        root.pending = false;
        root.available = false;
        root.count = 0;
    }

    Process {
        id: proc
        command: ["docker", "ps", "--quiet"]

        stdout: StdioCollector {
            onStreamFinished: root.count = this.text.split("\n").filter(line => line !== "").length
        }

        onExited: code => {
            root.pending = false;
            if (code === 0)
                root.available = true;
            else
                root.drop();
        }

        onRunningChanged: if (!running && root.pending)
            root.drop()
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
