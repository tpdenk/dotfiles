pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs

// The local docker engine: the containers it knows about, counted for the bar
// chip and listed in the panel.
Singleton {
    id: root

    readonly property bool expanded: Panels.open === "docker"

    readonly property int interval: 5000

    property bool available: false
    property var containers: []

    readonly property int count: containers.filter(entry => entry.running).length
    readonly property int stopped: containers.length - count
    readonly property int projects: new Set(containers.map(entry => entry.project).filter(name => name !== "")).size

    function rowFor(key: string, group: string, label: string, member: bool, members: var): var {
        const running = members.filter(entry => entry.running).length;
        return {
            key: key,
            group: group,
            label: label,
            member: member,
            ids: members.map(entry => entry.id),
            running: running,
            total: members.length,
            status: members.length > 1 ? `${running}/${members.length} up` : members[0].status
        };
    }

    // A compose project, its services indented under it, a service's replicas
    // collapsed into one row; containers started by hand stand on their own.
    // Every row acts on all the containers below it, as compose does.
    readonly property var rows: {
        const byProject = new Map();
        const entries = [];
        for (const container of root.containers) {
            if (container.project === "") {
                entries.push({
                    project: "",
                    name: container.name,
                    members: [container]
                });
                continue;
            }
            const entry = byProject.get(container.project);
            if (entry) {
                entry.members.push(container);
                continue;
            }
            const fresh = {
                project: container.project,
                name: container.project,
                members: [container]
            };
            byProject.set(container.project, fresh);
            entries.push(fresh);
        }

        // anything up first, then by name: the status text changes every poll,
        // and ordering on it would reshuffle the list under the cursor
        entries.sort((a, b) => (b.members.some(entry => entry.running) - a.members.some(entry => entry.running)) || a.name.localeCompare(b.name));

        const rows = [];
        for (const entry of entries) {
            if (entry.project === "") {
                rows.push(root.rowFor(entry.members[0].id, "", entry.name, false, entry.members));
                continue;
            }
            rows.push(root.rowFor(entry.project, "", entry.project, false, entry.members));

            // a stack from another tool carries a project but no service, and
            // each of its containers is then a service of its own
            const byService = new Map();
            for (const container of entry.members) {
                const service = container.service || container.name;
                const replicas = byService.get(service);
                if (replicas)
                    replicas.push(container);
                else
                    byService.set(service, [container]);
            }

            for (const service of Array.from(byService.keys()).sort((a, b) => a.localeCompare(b))) {
                const replicas = byService.get(service);
                const label = replicas.length > 1 ? `${service} (x${replicas.length})` : service;
                rows.push(root.rowFor(`${entry.project}/${service}`, entry.project, label, true, replicas));
            }
        }
        return rows;
    }

    readonly property string icon: String.fromCodePoint(0xf0868) // docker
    readonly property string label: String(count)

    property bool pending: false

    // one command at a time: `docker stop` sits for its ten second timeout,
    // and a second click would otherwise take the process out from under the
    // first
    property string busyKey: ""
    property bool busyStopping: false
    property var actionCommand: []

    function busy(row: var): bool {
        return root.busyKey !== "" && (row.key === root.busyKey || row.group === root.busyKey);
    }

    function stateLabel(row: var): string {
        if (root.busy(row))
            return root.busyStopping ? "stopping…" : "starting…";
        return row.status;
    }

    // a stack with only part of it up comes down whole, which is a state it is
    // meant to be in
    function activate(row: var): void {
        if (!row || root.busyKey !== "")
            return;
        root.busyKey = row.key;
        root.busyStopping = row.running > 0;
        root.actionCommand = ["docker", root.busyStopping ? "stop" : "start", ...row.ids];
        actionProc.running = true;
    }

    function refresh(): void {
        root.pending = true;
        proc.running = true;
    }

    function drop(): void {
        root.pending = false;
        root.available = false;
        root.containers = [];
    }

    Process {
        id: proc
        command: ["docker", "ps", "--all", "--format", '{{.ID}}\t{{.Names}}\t{{.State}}\t{{.Status}}\t{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.service"}}']

        stdout: StdioCollector {
            onStreamFinished: root.containers = root.parse(this.text)
        }

        onExited: code => {
            root.pending = false;
            if (code === 0)
                root.available = true;
            else
                root.drop();
        }

        // no docker binary at all drops `running` without ever reaching
        // `exited`, and the chip would keep its last count
        onRunningChanged: if (!running && root.pending)
            root.drop()
    }

    Process {
        id: actionProc
        command: root.actionCommand

        // the poll is up to five seconds away and the rows would sit on their
        // old state until then
        onExited: {
            root.busyKey = "";
            root.refresh();
        }

        onRunningChanged: if (!running)
            root.busyKey = ""
    }

    function parse(text: string): var {
        const rows = [];
        for (const line of text.split("\n")) {
            const [id, name, state, status, project, service] = line.split("\t");
            if (!id)
                continue;
            rows.push({
                id: id,
                name: name || id,
                running: state === "running",
                status: status ?? "",
                project: project ?? "",
                service: service ?? ""
            });
        }
        return rows.sort((a, b) => a.name.localeCompare(b.name));
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
