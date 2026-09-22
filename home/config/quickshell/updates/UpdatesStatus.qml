pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
    id: root

    readonly property bool expanded: Panels.open === "updates"

    readonly property int interval: 15000

    property var packages: []
    readonly property int count: packages.length

    property bool failed: false
    property bool pending: false

    readonly property var kernel: packages.find(entry => /^linux(-(lts|zen|hardened|rt|rt-lts))?$/.test(entry.name)) ?? null
    readonly property bool kernelUpdate: kernel !== null

    readonly property string icon: String.fromCodePoint(0xf03d5) // package-up
    readonly property string kernelIcon: String.fromCodePoint(0xf0ec0) // penguin

    readonly property string label: failed ? "?" : String(count)

    // one row per pkgbase: forty-odd qemu-* packages come out of one build,
    // carry one version and are upgraded together
    readonly property var groups: {
        const byBase = new Map();
        for (const entry of packages) {
            const group = byBase.get(entry.base);
            if (group) {
                group.names.push(entry.name);
                continue;
            }
            byBase.set(entry.base, {
                base: entry.base,
                names: [entry.name],
                installed: entry.installed,
                available: entry.available,
                kernel: entry.name === root.kernel?.name
            });
        }
        return Array.from(byBase.values()).sort((a, b) => (b.kernel - a.kernel) || a.base.localeCompare(b.base));
    }

    function groupLabel(group: var): string {
        return group.names.length > 1 ? `${group.base} (${group.names.length})` : group.base;
    }

    // the pkgrel is dropped unless it is the only thing that moved, which the
    // short form would otherwise print as "0.26.1 → 0.26.1"
    function versionLabel(group: var): string {
        const from = group.installed.replace(/^\d+:/, "");
        const to = group.available.replace(/^\d+:/, "");
        const rebuild = from.replace(/-[^-]*$/, "") === to.replace(/-[^-]*$/, "");
        return rebuild ? `${from} → -${to.split("-").pop()}` : `${from.replace(/-[^-]*$/, "")} → ${to.replace(/-[^-]*$/, "")}`;
    }

    // pacman and fwupdmgr want root and ask questions, so they run in a
    // terminal the answers can be typed into
    function run(args: var): void {
        Quickshell.execDetached(["xdg-terminal-exec", "sh", "-c", 'sudo "$@"; printf "\n[enter] to close"; read _', "updates", ...args]);
    }

    function updateAll(): void {
        Panels.close("updates");
        root.run(["pacman", "-Syu"]);
    }

    // one build on its own: a partial upgrade, which holds until a shared
    // library moves underneath something left behind
    function update(group: var): void {
        Panels.close("updates");
        root.run(["pacman", "-Sy", "--needed", ...group.names]);
    }

    function refresh(): void {
        root.pending = true;
        proc.running = true;
    }

    function fail(): void {
        root.packages = [];
        root.pending = false;
        root.failed = true;
    }

    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/bin/pkg-updates"]

        stdout: StdioCollector {
            onStreamFinished: root.packages = root.parse(this.text)
        }

        onExited: code => {
            root.pending = false;
            if (code === 0)
                root.failed = false;
            else
                root.fail();
        }

        // a script that cannot be run at all drops `running` without ever
        // reaching `exited`, and the chip would keep its last count
        onRunningChanged: if (!running && root.pending)
            root.fail()
    }

    function parse(text: string): var {
        const rows = [];
        for (const line of text.split("\n")) {
            const [name, base, installed, available] = line.split("\t");
            if (!name)
                continue;
            rows.push({
                name: name,
                base: base || name,
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
