pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import qs

// State of the machine's network interfaces: NetworkManager facts from
// Quickshell.Networking, plus latency/throughput measured for whichever
// interface the panel currently shows.
Singleton {
    id: root

    // metric polling and wifi scanning both follow the panel being open
    readonly property bool expanded: Panels.open === "network"

    readonly property var devices: Networking.devices.values.filter(d => d.type === DeviceType.Wired || d.type === DeviceType.Wifi)

    // the interface the bar icon speaks for. wired wins over wifi (NM routes
    // it first); an unplugged-but-present device still beats wifi so its tab
    // is the one offered first.
    readonly property var primary: devices.find(d => d.connected && d.type === DeviceType.Wired) ?? devices.find(d => d.connected) ?? devices.find(d => d.type === DeviceType.Wired && d.hasLink) ?? devices.find(d => d.type === DeviceType.Wifi) ?? devices[0] ?? null

    // the selected tab; null (or a vanished device) falls back to `primary`
    property var selected: null
    readonly property var device: selected && devices.includes(selected) ? selected : primary

    readonly property bool radioEnabled: Networking.wifiEnabled

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

    // "enabled" means NM is allowed to bring this interface up, whether or not
    // it happens to be associated right now. A manual disconnect clears
    // autoconnect, which is what makes the off state stick.
    function enabledOf(dev: var): bool {
        if (!dev)
            return false;
        if (dev.type === DeviceType.Wifi && !Networking.wifiEnabled)
            return false;
        return dev.connected || dev.autoconnect;
    }

    // Per interface, not global: NM's own device up/down, so disabling wifi
    // here leaves any other wireless device alone.
    function setEnabled(dev: var, on: bool): void {
        if (!dev)
            return;
        if (!on) {
            if (dev.connected)
                dev.disconnect();
            dev.autoconnect = false;
            return;
        }
        // a wifi device cannot come up while the radio is soft blocked
        if (dev.type === DeviceType.Wifi && !Networking.wifiEnabled)
            Networking.wifiEnabled = true;
        dev.autoconnect = true;
        (dev.network ?? dev.networks?.values.find(n => n.known))?.connect();
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

    function securityOf(net: var): string {
        return net ? WifiSecurityType.toString(net.security) : "";
    }

    function isOpen(net: var): bool {
        return net?.security === WifiSecurityType.Open || net?.security === WifiSecurityType.Owe;
    }

    // --- the bar icon: always the primary interface, whatever tab is open ---

    readonly property string icon: iconOf(primary)
    readonly property bool primaryConnected: primary?.connected ?? false

    // what the primary interface is attached to, in the width of a bar pill:
    // the SSID says more than "Wi-Fi" does, and a wired link has no name
    readonly property string barLabel: {
        if (!primary)
            return "No device";
        if (primary.type !== DeviceType.Wifi)
            return primary.connected ? "Wired" : primary.hasLink ? "Unused" : "Unplugged";
        if (!Networking.wifiEnabled)
            return "Off";
        return networkOf(primary)?.name || (primary.connected ? "Connected" : "Offline");
    }

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
    // until the first ping is in, the level is the signal alone, which would
    // call any strong but lossy link excellent
    readonly property bool qualityPending: polling && !pingMeasured
    readonly property string qualityLabel: qualityPending ? "Measuring…" : ["Offline", "Poor", "Fair", "Good", "Excellent"][quality]
    readonly property string security: securityOf(network)
    readonly property string wifiMode: wifi && device ? WifiDeviceMode.toString(device.mode) : ""

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

    // --- wifi scanning: only while its tab is on screen ---

    readonly property var scanTarget: expanded && radioEnabled && device?.type === DeviceType.Wifi ? device : null
    property var scanningDevice: null

    onScanTargetChanged: {
        if (scanningDevice === scanTarget)
            return;
        if (scanningDevice)
            scanningDevice.scannerEnabled = false;
        scanningDevice = scanTarget;
        if (scanningDevice)
            scanningDevice.scannerEnabled = true;
    }

    // connected first, then saved, then by signal bucket: sorting on the raw
    // signal would reshuffle the list on every scan update
    readonly property var wifiNetworks: {
        if (!wifi)
            return [];
        return (device?.networks?.values ?? []).filter(n => n.name).sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            const bucket = Math.ceil(b.signalStrength * 4) - Math.ceil(a.signalStrength * 4);
            return bucket !== 0 ? bucket : a.name.localeCompare(b.name);
        });
    }

    // --- joining ---

    // the network waiting for a password, if any
    property var pendingNetwork: null
    // the network whose activation is in flight
    property var joining: null
    property string joinError: ""

    function join(net: var): void {
        joinError = "";
        if (!net || net.connected)
            return;
        if (net.known || isOpen(net)) {
            joining = net;
            net.connect();
        } else {
            pendingNetwork = net;
        }
    }

    function submitPassword(psk: string): void {
        const net = pendingNetwork;
        pendingNetwork = null;
        if (!net)
            return;
        joinError = "";
        joining = net;
        net.connectWithPsk(psk);
    }

    function cancelJoin(): void {
        pendingNetwork = null;
        joinError = "";
    }

    Connections {
        target: root.joining

        function onConnectionFailed(reason: int): void {
            root.joinError = ConnectionFailReason.toString(reason);
            // a rejected or missing passphrase: ask again rather than making
            // the user hunt for the network in the list a second time
            if (reason === ConnectionFailReason.NoSecrets)
                root.pendingNetwork = root.joining;
            root.joining = null;
        }

        function onConnectedChanged(): void {
            if (root.joining?.connected) {
                root.joining = null;
                root.joinError = "";
            }
        }
    }

    // --- measured for `device` while the panel is open; -1 means "not yet" ---

    property real pingMs: -1
    property real packetLoss: -1
    // a ping has reported, even if it could not reach anything
    property bool pingMeasured: false
    property real rxRate: -1
    property real txRate: -1
    property string address: ""
    property string subnet: ""
    property var ipv6: []

    // the AP the wifi interface is associated with right now. One SSID can be
    // served by several APs (mesh, repeaters), so the BSSID is what tells them
    // apart; roaming to another one restarts the association clock.
    property string bssid: ""
    // wall clock ms, as reported by `iw`
    property real associatedAt: -1
    // ticks with the throughput sampler so the association age stays live
    property real now: Date.now()
    readonly property real associatedFor: associatedAt < 0 ? -1 : Math.max(0, (now - associatedAt) / 1000)

    // the manufacturer registered for the BSSID's OUI. A locally administered
    // BSSID (one radio serving several SSIDs) has none, so it stays empty.
    property var vendors: ({})
    readonly property string apOui: bssid.replace(/:/g, "").slice(0, 6).toUpperCase()
    readonly property string apVendor: vendors[apOui] ?? ""

    onApOuiChanged: lookupVendor()

    // --- pinning the profile to the current AP ---
    //
    // NM only configures the supplicant's roaming scan (bgscan) for a profile
    // that is free to roam; locking `802-11-wireless.bssid` turns it off,
    // which spares a full-band sweep every few minutes on a link that has
    // nowhere better to go. The profile is edited through nmcli: quickshell's
    // NMSettings.write() has no byte-array conversion for the bssid key.

    // the active profile of `device`, and its bssid lock if any
    property string profileUuid: ""
    property string pinnedBssid: ""
    readonly property bool pinned: pinnedBssid !== ""
    readonly property bool pinning: pinProc.running
    readonly property bool canPin: connected && bssid !== "" && profileUuid !== "" && !pinning

    // bgscan is set up when the connection activates, so the profile is
    // brought up again right after the edit: a few seconds offline either way
    function setPinned(on: bool): void {
        if (!canPin)
            return;
        pinProc.command = ["sh", "-c", 'nmcli connection modify uuid "$1" 802-11-wireless.bssid "$2" && exec nmcli connection up uuid "$1"', "wifi-pin", profileUuid, on ? bssid : ""];
        pinProc.running = true;
    }

    function parseProfile(text: string): void {
        const [uuid, lock] = text.split("\n");
        profileUuid = uuid ?? "";
        pinnedBssid = lock ?? "";
    }

    // default routes by interface, and which one the kernel actually picks:
    // interfaces on the same prefix are separated by metric, not by address
    property var defaultRoutes: ({})
    property string routedInterface: ""

    readonly property var route: defaultRoutes[device?.name ?? ""] ?? null
    readonly property string gateway: route?.gateway ?? ""
    readonly property int routeMetric: route ? route.metric : -1
    readonly property bool routed: !!device && device.name === routedInterface

    // a down interface has nothing to measure: pinging it would just report
    // 100% loss every 5s
    readonly property bool polling: expanded && connected

    onPollingChanged: restart()
    onDeviceChanged: restart()

    // stale numbers belong to the interface we just left
    function restart(): void {
        counters = null;
        pingMs = -1;
        packetLoss = -1;
        pingMeasured = false;
        rxRate = -1;
        txRate = -1;
        address = "";
        subnet = "";
        ipv6 = [];
        bssid = "";
        associatedAt = -1;
        profileUuid = "";
        pinnedBssid = "";
        refreshDelay.restart();
    }

    // one tick late so the `ping`/`ip` command bindings have picked up the new
    // interface name, and so `polling` has settled for the new selection;
    // also debounces rapid tab clicks
    Timer {
        id: refreshDelay
        interval: 50
        onTriggered: {
            if (!root.polling)
                return;
            root.sampleThroughput();
            root.measure();
        }
    }

    function measure(): void {
        if (!polling)
            return;
        if (!pingProc.running)
            pingProc.running = true;
        if (!addressProc.running)
            addressProc.running = true;
        if (!routeProc.running)
            routeProc.running = true;
        if (wifi && !stationProc.running)
            stationProc.running = true;
        if (wifi && !profileProc.running)
            profileProc.running = true;
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

    function formatDuration(seconds: real): string {
        const total = Math.floor(seconds);
        const days = Math.floor(total / 86400);
        const hours = Math.floor(total % 86400 / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        if (days > 0)
            return `${days}d ${hours}h`;
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return minutes > 0 ? `${minutes}m ${total % 60}s` : `${total}s`;
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
        pingMeasured = true;
    }

    function parseAddress(text: string): void {
        const info = JSON.parse(text)[0]?.addr_info ?? [];
        const v4 = info.find(a => a.family === "inet" && a.scope === "global");
        address = v4 ? `${v4.local}/${v4.prefixlen}` : "";
        subnet = v4 ? cidr(v4.local, v4.prefixlen) : "";
        // routable addresses first, link-local last; deprecated privacy
        // addresses are on their way out and would only add noise
        ipv6 = info.filter(a => a.family === "inet6" && !a.deprecated).sort((a, b) => (a.scope === "link") - (b.scope === "link")).map(a => `${a.local}/${a.prefixlen}`);
    }

    // the network the address sits in, e.g. 192.168.178.41/24 -> 192.168.178.0/24
    function cidr(ip: string, prefix: int): string {
        const octets = ip.split(".").map(o => parseInt(o));
        if (octets.length !== 4 || octets.some(o => isNaN(o)))
            return "";
        const value = octets.reduce((acc, o) => (acc << 8 | o) >>> 0, 0);
        // a /0 mask cannot be expressed by shifting 32 bits
        const mask = prefix === 0 ? 0 : 0xffffffff << 32 - prefix >>> 0;
        const network = (value & mask) >>> 0;
        return `${network >>> 24}.${network >>> 16 & 255}.${network >>> 8 & 255}.${network & 255}/${prefix}`;
    }

    // `iw dev X station dump`: one block per peer, which for a client is the
    // AP plus any TDLS peers
    function parseStation(text: string): void {
        const ap = text.split(/^Station /m).slice(1).find(b => !/^\s*TDLS peer:\s*yes/m.test(b));
        bssid = ap?.match(/^([0-9a-f:]{17})\b/)?.[1] ?? "";
        const at = ap?.match(/^\s*associated at:\s*(\d+) ms/m);
        associatedAt = at ? parseFloat(at[1]) : -1;
        now = Date.now();
    }

    function lookupVendor(): void {
        if (!apOui || apOui in vendors || vendorProc.running)
            return;
        vendorProc.oui = apOui;
        vendorProc.command = ["systemd-hwdb", "query", `OUI:${apOui}`];
        vendorProc.running = true;
    }

    // `ip route show default` for every interface at once: the lowest metric is
    // the one the kernel sends through when the prefixes tie
    function parseRoutes(text: string): void {
        const routes = {};
        let best = "";
        let bestMetric = Infinity;
        for (const r of JSON.parse(text)) {
            if (r.dst !== "default" || !r.dev)
                continue;
            const metric = r.metric ?? 0;
            if (!routes[r.dev] || metric < routes[r.dev].metric)
                routes[r.dev] = {
                    metric: metric,
                    gateway: r.gateway ?? ""
                };
            if (metric < bestMetric) {
                bestMetric = metric;
                best = r.dev;
            }
        }
        defaultRoutes = routes;
        routedInterface = best;
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
        // no -4: v4 and v6 addresses come back in one call
        command: ["ip", "-json", "addr", "show", "dev", root.device?.name ?? ""]

        stdout: StdioCollector {
            onStreamFinished: root.parseAddress(this.text)
        }
    }

    Process {
        id: routeProc
        command: ["ip", "-json", "-4", "route", "show", "default"]

        stdout: StdioCollector {
            onStreamFinished: root.parseRoutes(this.text)
        }
    }

    Process {
        id: stationProc
        command: ["iw", "dev", root.device?.name ?? "", "station", "dump"]

        stdout: StdioCollector {
            onStreamFinished: root.parseStation(this.text)
        }
    }

    // the connection's uuid is what `nmcli connection modify` needs; the name
    // is not unique across profiles for one SSID
    Process {
        id: profileProc
        command: ["sh", "-c", 'u=$(nmcli -g GENERAL.CON-UUID device show "$1") && printf "%s\\n%s\\n" "$u" "$(nmcli --escape no -g 802-11-wireless.bssid connection show uuid "$u")"', "wifi-profile", root.device?.name ?? ""]

        stdout: StdioCollector {
            onStreamFinished: root.parseProfile(this.text)
        }
    }

    Process {
        id: pinProc

        // the toggle reflects the profile, not the click, so it snaps back on
        // failure as well as forward on success
        onRunningChanged: {
            if (!running && !profileProc.running)
                profileProc.running = true;
        }
    }

    Process {
        id: vendorProc
        property string oui

        stdout: StdioCollector {
            // a miss prints nothing and is cached as such
            onStreamFinished: root.vendors = Object.assign({}, root.vendors, {
                [vendorProc.oui]: this.text.match(/^ID_OUI_FROM_DATABASE=(.*)$/m)?.[1] ?? ""
            })
        }

        // the AP may have changed while this query ran
        onRunningChanged: {
            if (!running)
                root.lookupVendor();
        }
    }

    Timer {
        interval: 1000
        running: root.polling
        repeat: true
        onTriggered: {
            root.now = Date.now();
            root.sampleThroughput();
        }
    }

    Timer {
        interval: 5000
        running: root.polling
        repeat: true
        onTriggered: root.measure()
    }
}
