pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// State of the primary network connection: NetworkManager facts from
// Quickshell.Networking plus latency/throughput, sampled while `expanded`.
Singleton {
    id: root

    // whether the details panel is open; metric polling follows it
    property bool expanded: false

    readonly property var devices: Networking.devices.values.filter(d => d.type === DeviceType.Wired || d.type === DeviceType.Wifi)

    // the connection the bar speaks for. wired wins over wifi (NM routes it
    // first); an unplugged-but-present device still beats wifi so the toggle
    // can bring it back up.
    readonly property var device: devices.find(d => d.connected && d.type === DeviceType.Wired) ?? devices.find(d => d.connected) ?? devices.find(d => d.type === DeviceType.Wired && d.hasLink) ?? devices.find(d => d.type === DeviceType.Wifi) ?? devices[0] ?? null

    readonly property bool wifi: device?.type === DeviceType.Wifi
    readonly property bool connected: device?.connected ?? false
    // wifi: the associated AP; wired: the device's connection profile
    readonly property var network: wifi ? device?.networks?.values.find(n => n.connected) ?? null : device?.network ?? null

    readonly property string name: network?.name ?? ""
    // 0-1, wifi only; a wired link is either full strength or nothing
    readonly property real signalStrength: wifi ? network?.signalStrength ?? 0 : device?.hasLink ? 1 : 0
    readonly property int linkSpeed: device?.linkSpeed ?? 0
    readonly property string status: device ? ConnectionState.toString(device.state) : "No device"

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

    // wifi: the rfkill soft block; wired: the link itself, which NM keeps down
    // (autoconnect blocked) until explicitly reconnected
    readonly property bool enabled: wifi ? Networking.wifiEnabled : connected

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

    // 0-4: signal, capped by measured latency and loss
    readonly property int quality: {
        if (!connected)
            return 0;
        let level = wifi ? Math.max(1, Math.ceil(signalStrength * 4)) : 4;
        if (packetLoss >= 50)
            level = Math.min(level, 1);
        else if (packetLoss > 5 || pingMs > 200)
            level = Math.min(level, 2);
        else if (pingMs > 100)
            level = Math.min(level, 3);
        return level;
    }

    readonly property string qualityLabel: ["Offline", "Poor", "Fair", "Good", "Excellent"][quality]

    // wired: the jack, crossed-out cable when the link is down.
    // wifi: the wedge filled to `quality`, hollow when associated with
    // nothing, crossed out when the radio is off.
    readonly property string icon: {
        if (!wifi)
            return String.fromCodePoint(connected ? 0xf0200 : 0xf0202); // ethernet, ethernet cable off
        if (!Networking.wifiEnabled)
            return String.fromCodePoint(0xf05aa); // wifi off
        if (!connected)
            return String.fromCodePoint(0xf092f); // wifi strength outline
        return String.fromCodePoint([0xf091f, 0xf091f, 0xf0922, 0xf0925, 0xf0928][quality]);
    }

    // measured while the panel is open; -1 means "not sampled yet"
    property real pingMs: -1
    property real packetLoss: -1
    property real rxRate: -1
    property real txRate: -1
    property string address: ""

    readonly property bool polling: expanded && !!device

    onPollingChanged: {
        counters = null;
        pingMs = -1;
        packetLoss = -1;
        rxRate = -1;
        txRate = -1;
    }

    onDeviceChanged: {
        counters = null;
        address = "";
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
        command: ["ping", "-n", "-q", "-c", "3", "-i", "0.2", "-W", "1", "1.1.1.1"]

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
        triggeredOnStart: true
        onTriggered: root.sampleThroughput()
    }

    Timer {
        interval: 5000
        running: root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pingProc.running)
                pingProc.running = true;
            if (!addressProc.running)
                addressProc.running = true;
        }
    }
}
