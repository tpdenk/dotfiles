pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
    id: root

    readonly property int interval: 300000

    property var devices: []
    readonly property int count: devices.length

    property bool failed: false
    property bool pending: false

    readonly property string icon: String.fromCodePoint(0xf061a) // chip
    readonly property string label: failed ? "?" : String(count)

    function versionLabel(device: var): string {
        return `${device.installed} → ${device.available}`;
    }

    function update(device: var): void {
        Panels.close("updates");
        UpdatesStatus.run(["fwupdmgr", "update", device.id]);
    }

    function refresh(): void {
        root.pending = true;
        proc.running = true;
    }

    function fail(): void {
        root.devices = [];
        root.pending = false;
        root.failed = true;
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/fw-updates"]

        stdout: StdioCollector {
            onStreamFinished: root.devices = root.parse(this.text)
        }

        onExited: code => {
            root.pending = false;
            if (code === 0)
                root.failed = false;
            else
                root.fail();
        }

        onRunningChanged: if (!running && root.pending)
            root.fail()
    }

    function parse(text: string): var {
        const rows = [];
        for (const line of text.split("\n")) {
            const [id, name, installed, available] = line.split("\t");
            if (!id)
                continue;
            rows.push({
                id: id,
                name: name || id,
                installed: installed ?? "",
                available: available ?? ""
            });
        }
        return rows;
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
