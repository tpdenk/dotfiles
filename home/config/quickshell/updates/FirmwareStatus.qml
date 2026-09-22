pragma Singleton
import Quickshell
import qs

// Pending firmware upgrades, as `fw-updates` lists them from fwupd.
Singleton {
    id: root

    property var devices: []
    readonly property int count: devices.filter(d => !d.blocked).length
    readonly property int blocked: devices.length - count
    property bool failed: false

    readonly property string icon: String.fromCodePoint(0xf061a) // chip
    readonly property string label: failed ? "?" : String(devices.length)

    function versionLabel(device: var): string {
        return device.blocked ? device.blocked : `${device.installed} → ${device.available}`;
    }

    function update(device: var): void {
        if (!device.blocked)
            UpdatesStatus.runInTerminal(["fwupdmgr", "update", device.id]);
    }

    Poll {
        command: [Quickshell.env("HOME") + "/.local/bin/fw-updates"]
        interval: 300000

        onFinished: text => {
            root.devices = root.parse(text);
            root.failed = false;
        }
        onFailed: {
            root.devices = [];
            root.failed = true;
        }
    }

    function parse(text: string): var {
        const rows = [];
        for (const line of text.split("\n")) {
            const [id, name, installed, available, blocked] = line.split("\t");
            if (!id)
                continue;
            rows.push({
                id: id,
                name: name || id,
                installed: installed ?? "",
                available: available ?? "",
                blocked: blocked ?? ""
            });
        }
        return rows;
    }
}
