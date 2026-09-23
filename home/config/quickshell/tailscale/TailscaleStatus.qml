pragma Singleton
import Quickshell
import Quickshell.Io
import qs

// The local tailscaled: whether this node is on the tailnet, its addresses,
// and the peers it can see, for the bar pill and its panel. Needs `tailscale
// set --operator=$USER` for the toggle to work without root.
Singleton {
    id: root

    property bool available: false
    // tailscaled's ipn.State: NoState, NeedsLogin, NeedsMachineAuth, Stopped,
    // Starting, Running
    property string state: ""
    property string hostName: ""
    property string dnsName: ""
    property string address: ""
    property string tailnet: ""
    property string exitNode: ""
    property var peers: []

    readonly property bool running: state === "Running"
    readonly property int online: peers.filter(peer => peer.online).length

    readonly property string label: {
        switch (state) {
        case "Running":
            return String(online);
        case "Stopped":
            return "Off";
        case "NeedsLogin":
        case "NeedsMachineAuth":
            return "Login";
        default:
            return state;
        }
    }

    readonly property string status: {
        if (busy)
            return busyStopping ? "Disconnecting…" : "Connecting…";
        switch (state) {
        case "Running":
            return "Connected";
        case "Stopped":
            return "Disconnected";
        case "NeedsLogin":
            return "Needs login";
        case "NeedsMachineAuth":
            return "Awaiting admin approval";
        case "":
            return "Daemon not running";
        default:
            return state;
        }
    }

    // a MagicDNS name's first label: phones report their HostName as
    // "localhost", which `tailscale status` also papers over this way
    function shortName(node: var): string {
        return (node?.DNSName ?? "").split(".")[0] || node?.HostName || "";
    }

    // one at a time, and only between the two settled states: `tailscale up`
    // from NeedsLogin would sit waiting on a browser login nobody sees
    property bool busy: false
    property bool busyStopping: false
    readonly property bool toggleable: !busy && (state === "Running" || state === "Stopped")

    function setEnabled(on: bool): void {
        if (!root.toggleable || on === root.running)
            return;
        root.busy = true;
        root.busyStopping = !on;
        toggleProc.command = ["tailscale", on ? "up" : "down"];
        toggleProc.running = true;
    }

    Process {
        id: toggleProc

        // the poll is up to five seconds away and the panel would sit on its
        // old state until then
        onRunningChanged: {
            if (running)
                return;
            root.busy = false;
            poll.refresh();
        }
    }

    // a missing binary or a stopped daemon both fail the same way: the chip
    // hides. `tailscale down` still answers, as state "Stopped".
    Poll {
        id: poll
        command: ["tailscale", "status", "--json"]
        interval: 5000

        onFinished: text => {
            let status;
            try {
                status = JSON.parse(text);
            } catch (e) {
                root.reset();
                return;
            }
            const self = status.Self ?? {};
            root.state = status.BackendState ?? "";
            root.hostName = root.shortName(self);
            root.dnsName = (self.DNSName ?? "").replace(/\.$/, "");
            root.address = (status.TailscaleIPs ?? [])[0] ?? "";
            root.tailnet = self.CapMap?.["tailnet-display-name"]?.[0] ?? status.CurrentTailnet?.Name ?? "";

            const peers = Object.values(status.Peer ?? {}).map(peer => ({
                        name: root.shortName(peer),
                        os: peer.OS ?? "",
                        address: (peer.TailscaleIPs ?? [])[0] ?? "",
                        online: peer.Online === true,
                        exitNode: peer.ExitNode === true
                    }));
            // online first, then by name: nothing that changes between polls
            // may decide the order, or the list reshuffles under the cursor
            peers.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
            root.peers = peers;
            root.exitNode = peers.find(peer => peer.exitNode)?.name ?? "";
            root.available = true;
        }
        onFailed: root.reset()
    }

    function reset(): void {
        root.available = false;
        root.state = "";
        root.hostName = "";
        root.dnsName = "";
        root.address = "";
        root.tailnet = "";
        root.exitNode = "";
        root.peers = [];
    }
}
