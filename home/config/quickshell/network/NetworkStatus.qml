pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// State of the machine's network interfaces: NetworkManager facts from
// Quickshell.Networking, plus latency/throughput measured for whichever
// interface the panel currently shows.
Singleton {
    id: root

    // whether the details panel is open; metric polling follows it
    property bool expanded: false

    readonly property var devices: Networking.devices.values.filter(d => d.type === DeviceType.Wired || d.type === DeviceType.Wifi)

    // the interface the bar icon speaks for. wired wins over wifi (NM routes
    // it first); an unplugged-but-present device still beats wifi so its tab
    // is the one offered first.
    readonly property var primary: devices.find(d => d.connected && d.type === DeviceType.Wired) ?? devices.find(d => d.connected) ?? devices.find(d => d.type === DeviceType.Wired && d.hasLink) ?? devices.find(d => d.type === DeviceType.Wifi) ?? devices[0] ?? null

    // the selected tab; null (or a vanished device) falls back to `primary`
    property var selected: null
    readonly property var device: selected && devices.includes(selected) ? selected : primary

    // --- per device, so both the bar icon and any tab can be described ---

    // wifi: the associated AP; wired: the device's connection profile
    function networkOf(dev: var): var {
        if (!dev)
            return null;
        return dev.type === DeviceType.Wifi ? dev.networks?.values.find(n => n.connected) ?? null : dev.network ?? null;
    }

    // 0-1, wifi only; a wired link is either full strength or nothing
    function signalOf(dev: var): real {
        if (!dev)
            return 0;
        if (dev.type !== DeviceType.Wifi)
            return dev.hasLink ? 1 : 0;
        return networkOf(dev)?.signalStrength ?? 0;
    }

    // wifi: the rfkill soft block; wired: the link itself, which NM keeps down
    // (autoconnect blocked) until explicitly reconnected
    function enabledOf(dev: var): bool {
        if (!dev)
            return false;
        return dev.type === DeviceType.Wifi ? Networking.wifiEnabled : dev.connected;
    }

    // 0-4: signal, capped by latency and loss where those are measured
    function qualityOf(dev: var): int {
        if (!dev?.connected)
            return 0;
        let level = dev.type === DeviceType.Wifi ? Math.max(1, Math.ceil(signalOf(dev) * 4)) : 4;
        if (dev === device) {
            if (packetLoss >= 50)
                level = Math.min(level, 1);
            else if (packetLoss > 5 || pingMs > 200)
                level = Math.min(level, 2);
            else if (pingMs > 100)
                level = Math.min(level, 3);
        }
        return level;
    }

    // wired: the jack, crossed-out cable when the link is down.
    // wifi: the wedge filled to the quality level, hollow when associated with
    // nothing, crossed out when the radio is off.
    function iconOf(dev: var): string {
        if (!dev || dev.type !== DeviceType.Wifi)
            return String.fromCodePoint(dev?.connected ? 0xf0200 : 0xf0202); // ethernet, ethernet cable off
        if (!Networking.wifiEnabled)
            return String.fromCodePoint(0xf05aa); // wifi off
        if (!dev.connected)
            return String.fromCodePoint(0xf092f); // wifi strength outline
        return String.fromCodePoint([0xf091f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][qualityOf(dev)]);
    }

    // --- the bar icon: always the primary interface, whatever tab is open ---

    readonly property string icon: iconOf(primary)
    readonly property bool primaryConnected: primary?.connected ?? false

    // --- the selected tab ---

    readonly property bool wifi: device?.type === DeviceType.Wifi
    readonly property bool connected: device?.connected ?? false
    readonly property var network: networkOf(device)
    readonly property string name: network?.name ?? ""
    readonly property real signalStrength: signalOf(device)
    readonly property int linkSpeed: device?.linkSpeed ?? 0
    readonly property string status: device ? ConnectionState.toString(device.state) : "No device"
    readonly property bool enabled: enabledOf(device)
    readonly property int quality: qualityOf(device)
    readonly property string qualityLabel: ["Offline", "Poor", "Fair", "Good", "Excellent"][quality]

    // NetworkManager-wide, not per interface
    readonly property string connectivity: {
        switch (Networking.connectivity) {
        case NetworkConnectivity.Full:
            return "Internet";
        case NetworkConnectivity.Portal:
            return "Captive portal";
        case NetworkConnectivity.Limited:
            return "No internet";
        case NetworkConnectivity.None:
            return "No network";
        default:
            return "Unknown";
        }
    }

    function setEnabled(on: bool): void {
        if (!device)
            return;
        if (device.type === DeviceType.Wifi)
            Networking.wifiEnabled = on;
        else if (on)
            (device.network ?? device.networks.values.find(n => n.known))?.connect();
        else
            device.disconnect();
    }

    // measured for `device` while the panel is open; -1 means "not sampled yet"
    property real pingMs: -1
    property real packetLoss: -1
    property real rxRate: -1
    property real txRate: -1
    property string address: ""

    readonly property bool polling: expanded && !!device

    onPollingChanged: restart()
    onDeviceChanged: restart()

    // stale numbers belong to the interface we just left
    function restart(): void {
        counters = null;
        pingMs = -1;
        packetLoss = -1;
        rxRate = -1;
        txRate = -1;
        address = "";
        if (polling)
            refreshDelay.restart();
    }

    // one tick late so the `ping`/`ip` command bindings have picked up the new
    // interface name; also debounces rapid tab clicks
    Timer {
        id: refreshDelay
        interval: 50
        onTriggered: {
            root.sampleThroughput();
            root.measure();
        }
    }

    function measure(): void {
        if (!pingProc.running)
            pingProc.running = true;
        if (!addressProc.running)
            addressProc.running = true;
    }

    function formatRate(rate: real): string {
        if (rate < 0)
            return "—";
        const units = ["B", "KiB", "MiB", "GiB"];
        let i = 0;
        while (rate >= 1024 && i < units.length - 1) {
            rate /= 1024;
            ++i;
        }
        return `${i === 0 ? Math.round(rate) : rate.toFixed(1)} ${units[i]}/s`;
    }

    // [rx bytes, tx bytes, ms] of the previous /proc/net/dev read
    property var counters: null

    function sampleThroughput(): void {
        procNetDev.reload();
        const now = Date.now();
        const sample = readCounters(procNetDev.text(), device?.name ?? "");
        if (sample && counters) {
            const seconds = (now - counters[2]) / 1000;
            if (seconds > 0) {
                rxRate = Math.max(0, (sample[0] - counters[0]) / seconds);
                txRate = Math.max(0, (sample[1] - counters[1]) / seconds);
            }
        }
        counters = sample ? [sample[0], sample[1], now] : null;
    }

    // `iface: rx_bytes rx_packets ... (8 rx fields) tx_bytes ...`
    function readCounters(text: string, iface: string): var {
        for (const line of text.split("\n")) {
            const m = line.match(/^\s*([^\s:]+):\s*(.*)$/);
            if (!m || m[1] !== iface)
                continue;
            const fields = m[2].trim().split(/\s+/);
            return [parseInt(fields[0]), parseInt(fields[8])];
        }
        return null;
    }

    function parsePing(text: string): void {
        const loss = text.match(/([\d.]+)% packet loss/);
        packetLoss = loss ? parseFloat(loss[1]) : -1;
        const rtt = text.match(/^rtt \S+ = [\d.]+\/([\d.]+)\//m);
        pingMs = rtt ? parseFloat(rtt[1]) : -1;
    }

    function parseAddress(text: string): void {
        const info = JSON.parse(text)[0]?.addr_info?.[0];
        address = info ? `${info.local}/${info.prefixlen}` : "";
    }

    FileView {
        id: procNetDev
        path: "/proc/net/dev"
        blockLoading: true
    }

    Process {
        id: pingProc
        // -I: latency of this interface, not of whatever the default route is
        command: ["ping", "-n", "-q", "-c", "3", "-i", "0.2", "-W", "1", "-I", root.device?.name ?? "", "1.1.1.1"]

        stdout: StdioCollector {
            onStreamFinished: root.parsePing(this.text)
        }
    }

    Process {
        id: addressProc
        command: ["ip", "-json", "-4", "addr", "show", "dev", root.device?.name ?? ""]

        stdout: StdioCollector {
            onStreamFinished: root.parseAddress(this.text)
        }
    }

    Timer {
        interval: 1000
        running: root.polling
        repeat: true
        onTriggered: root.sampleThroughput()
    }

    Timer {
        interval: 5000
        running: root.polling
        repeat: true
        onTriggered: root.measure()
    }
}
