pragma Singleton
import Quickshell
import qs

// Pending pacman upgrades, as `pkg-updates` lists them: counted for the bar
// chip, grouped by build for the panel.
Singleton {
    id: root

    property var packages: []
    readonly property int count: packages.length
    property bool failed: false

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
        const pkgver = version => version.replace(/-[^-]*$/, "");
        if (pkgver(from) === pkgver(to))
            return `${from} → -${to.split("-").pop()}`;
        return `${pkgver(from)} → ${pkgver(to)}`;
    }

    // pacman and fwupdmgr want root and ask questions, so they run in a
    // terminal the answers can be typed into, and the panel gets out of the
    // way of it
    function runInTerminal(args: var): void {
        Panels.close("updates");
        Quickshell.execDetached(["xdg-terminal-exec", "sh", "-c", 'sudo "$@"; printf "\n[enter] to close"; read _', "updates", ...args]);
    }

    function updateAll(): void {
        root.runInTerminal(["pacman", "-Syu"]);
    }

    // one build on its own: a partial upgrade, which holds until a shared
    // library moves underneath something left behind
    function update(group: var): void {
        root.runInTerminal(["pacman", "-Sy", "--needed", ...group.names]);
    }

    Poll {
        command: [Quickshell.env("HOME") + "/.local/bin/pkg-updates"]
        interval: 15000

        onFinished: text => {
            root.packages = root.parse(text);
            root.failed = false;
        }
        onFailed: {
            root.packages = [];
            root.failed = true;
        }
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
}
