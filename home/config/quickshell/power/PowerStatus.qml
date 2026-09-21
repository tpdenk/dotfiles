pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import qs

// Uptime, battery, per-device power draw and the active power profile.
Singleton {
    id: root

    readonly property bool expanded: Panels.open === "power"

    // --- battery ---

    // upower's display device folds a machine's batteries into one, and still
    // exists (reporting nothing present) on a machine without any
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isPresent ?? false
    readonly property real charge: battery?.percentage ?? 0

    readonly property int batteryState: battery?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: batteryState === UPowerDeviceState.Charging || batteryState === UPowerDeviceState.PendingCharge
    readonly property bool discharging: batteryState === UPowerDeviceState.Discharging

    // a magnitude; `state` says which way it flows
    readonly property real changeRate: battery?.changeRate ?? 0

    readonly property string batteryLabel: hasBattery ? `${Math.round(charge)}% ${UPowerDeviceState.toString(batteryState).toLowerCase()}` : UPower.onBattery ? "On battery" : "Plugged in"

    // upower leaves the estimate at 0 until it has watched the rate a while
    readonly property string rateLabel: {
        if (!hasBattery || changeRate <= 0)
            return "—";
        const watts = `${changeRate.toFixed(1)} W`;
        const left = discharging ? battery.timeToEmpty : charging ? battery.timeToFull : 0;
        return left > 0 ? `${watts} · ${duration(left)} ${discharging ? "left" : "to full"}` : watts;
    }

    // --- uptime ---

    readonly property string uptime: duration(parseFloat(uptimeFile.text()) || 0)

    FileView {
        id: uptimeFile
        path: "/proc/uptime" // first field is seconds since boot
        blockLoading: true
    }

    function duration(seconds: real): string {
        const total = Math.max(0, Math.round(seconds));
        const days = Math.floor(total / 86400);
        const hours = Math.floor(total % 86400 / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        if (days > 0)
            return `${days}d ${hours}h`;
        if (hours > 0)
            return `${hours}h ${minutes}m`;
        return `${minutes}m`;
    }

    // --- per-device draw ---

    property var sensors: []

    // An APU's PPT and a CPU driver's RAPL counter are one package measured
    // twice: AMD's package energy MSR covers the graphics block too. They
    // never quite agree, so only the firmware-averaged PPT is kept.
    readonly property var draws: {
        const rows = sensors.slice();
        if (hasBattery && changeRate > 0)
            rows.push({
                kind: "system",
                label: battery.model || "Battery",
                watts: changeRate
            });
        const packaged = rows.some(row => row.kind === "apu");
        return rows.filter(row => !(packaged && row.kind === "cpu")).sort((a, b) => b.watts - a.watts);
    }

    readonly property real peakWatts: Math.max(1, ...draws.map(row => row.watts))

    Process {
        id: drawProc
        command: [Quickshell.env("HOME") + "/.local/bin/power-draw"]

        stdout: StdioCollector {
            onStreamFinished: root.sensors = root.parseSensors(this.text)
        }
    }

    // `<microwatts>\t<chip>\t<label>\t<kind>\t<device name>\t<device node>`
    function parseSensors(text: string): var {
        const rows = [];
        for (const line of text.split("\n")) {
            const [microwatts, chip, label, kind, name, node] = line.split("\t");
            if (!microwatts)
                continue;
            rows.push({
                kind: kind,
                label: describeSensor(kind, chip, label, name ?? "", node ?? ""),
                watts: parseInt(microwatts) / 1e6
            });
        }
        return rows;
    }

    // hwmon publishes register names; the script resolves the machine's name
    // for the part. Where it could not, the driver name stands in.
    function describeSensor(kind: string, chip: string, label: string, name: string, node: string): string {
        switch (kind) {
        case "cpu":
        case "apu":
            return processorName(name) || "CPU";
        case "gpu":
            return deviceName(name) || "GPU";
        case "disk":
            // two identical disks are told apart by their kernel name
            return name ? (node ? `${name} (${node})` : name) : "Storage";
        case "wifi":
            return deviceName(name) || "Wi-Fi";
        case "net":
            return deviceName(name) || "Ethernet";
        case "charger":
            const port = chip.match(/USBC\d*:0*(\d+)$/);
            return port ? `Charger (USB-C port ${port[1]})` : "Charger";
        case "system":
            return name || "System";
        default:
            return `${chip} ${label.toLowerCase()}`.trim();
        }
    }

    // "AMD RYZEN AI MAX+ 395 w/ Radeon 8060S" -> "AMD Ryzen AI Max+ 395",
    // "Intel(R) Core(TM) i7-1185G7 CPU @ 3.00GHz" -> "Intel Core i7-1185G7".
    // Firmware shouts; words carrying a number are part numbers, left alone.
    function processorName(model: string): string {
        const cpu = model.split(/\s+w\/\s+/)[0].replace(/\s+(CPU|APU|Processor)\b.*$/, "");
        return cleanName(cpu).split(" ").map(word => word.length > 3 && word === word.toUpperCase() && !/\d/.test(word) ? word[0] + word.slice(1).toLowerCase() : word).join(" ");
    }

    // pci.ids hides the marketing name in brackets behind a codename, and
    // lists variants sharing one id after a slash:
    // "Navi 31 [Radeon RX 7900 XT/7900 XTX]" -> "Radeon RX 7900 XT"
    function deviceName(name: string): string {
        const bracket = name.match(/\[([^\]]+)\]/);
        return cleanName((bracket ? bracket[1] : name).split("/")[0].replace(/\s*\(.*$/, ""));
    }

    function cleanName(name: string): string {
        return name.replace(/\((R|TM)\)/gi, "").replace(/\b(Corporation|Corp\.?|Inc\.?|Co\.,? Ltd\.?|Semiconductor|Technologies|Devices|Advanced Micro|Controller|Adapter)\b/g, "").replace(/[\s,]{2,}/g, " ").replace(/\s+,/g, "").trim();
    }

    // --- power profile ---

    // `label` names the profile in the panel's switch, `short` in the bar pill
    readonly property var profiles: [
        {
            label: "Eco",
            short: "Eco",
            value: PowerProfile.PowerSaver,
            glyph: 0xf032a // leaf
        },
        {
            label: "Normal",
            short: "Norm",
            value: PowerProfile.Balanced,
            glyph: 0xf05d1 // scale-balance
        },
        {
            label: "Performance",
            short: "Perf",
            value: PowerProfile.Performance,
            // mdi's flash is 18px of ink where the other two are 13px: at one
            // point size it still reads as the larger glyph
            glyph: 0xf04c5 // speedometer
        }
    ]

    readonly property int profile: PowerProfiles.profile
    readonly property int profileIndex: profilesAvailable ? profiles.findIndex(entry => entry.value === profile) : -1

    // quickshell reports Balanced whether the daemon answered or is not
    // installed at all, and drops writes to a missing daemon with only a log
    // line, so the switch would silently snap back without this
    property bool profilesAvailable: false

    Process {
        id: profileCheck
        command: ["systemctl", "is-active", "--quiet", "power-profiles-daemon.service"]

        // the bar needs the profile before the panel is ever opened
        Component.onCompleted: running = true

        onExited: code => root.profilesAvailable = code === 0
    }

    function setProfile(index: int): void {
        const wanted = profiles[index];
        if (wanted)
            PowerProfiles.profile = wanted.value;
    }

    // --- polling: only while the panel is on screen ---

    Timer {
        interval: 2000
        running: root.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            uptimeFile.reload();
            drawProc.running = true;
        }
    }

    // whether the daemon exists changes only when packages do
    onExpandedChanged: if (expanded)
        profileCheck.running = true

    // --- bar entry ---

    readonly property bool low: hasBattery && !charging && charge <= 15

    // mdi's battery ramp in tens, charging having its own set. Index 0 is the
    // alert glyph, index 10 the full one.
    readonly property var dischargeGlyphs: [0xf0083, 0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079]
    readonly property var chargeGlyphs: [0xf089f, 0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d, 0xf0089, 0xf089e, 0xf008a, 0xf008b, 0xf0085]

    readonly property string batteryIcon: {
        if (!hasBattery)
            return "";
        const step = Math.max(0, Math.min(10, Math.round(charge / 10)));
        return String.fromCodePoint((charging ? chargeGlyphs : dischargeGlyphs)[step]);
    }

    // the bar pill's text: the charge when there is a battery, otherwise the
    // profile, which is all a desk machine's power state has to say
    readonly property string barLabel: hasBattery ? `${Math.round(charge)}%` : profileShort

    readonly property string profileIcon: profileIndex >= 0 ? String.fromCodePoint(profiles[profileIndex].glyph) : ""
    readonly property string profileShort: profileIndex >= 0 ? profiles[profileIndex].short : ""

    // no battery and no profile daemon: without this there would be nothing
    // to click
    readonly property string fallbackIcon: String.fromCodePoint(0xf06a5) // power-plug
}
