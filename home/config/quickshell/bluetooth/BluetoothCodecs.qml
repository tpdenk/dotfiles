pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs

// The audio codec each connected bluetooth device runs on, and the ones
// PipeWire would offer it instead, read and switched through pipewire-pulse's
// bluez card messages while the panel is open.
Singleton {
    id: root

    // address -> { codec: "4" | null, codecs: [{ name: "4", description: "AAC" }, …] }
    // only ever holds the connected devices from the last poll, so a device
    // that disconnects drops out on the next refresh
    property var byAddress: ({})
    // the device whose switch-codec is in flight, "" when none
    property string busyAddress: ""
    // XXX throwaway smoke hooks
    property bool dbgOpen: false
    IpcHandler {
        target: "btdbg"
        function open(on: bool): void { root.dbgOpen = on; }
        function pick(address: string, index: int): void { root.setCodec({ address }, index); }
        function dump(): string { return JSON.stringify(root.byAddress) + " busy=" + root.busyAddress; }
    }

    readonly property var addresses: BluetoothStatus.devices.filter(d => d.connected).map(d => d.address)
    readonly property bool polling: BluetoothStatus.expanded && addresses.length > 0

    // codec descriptions PipeWire offers the device on its current profile;
    // empty for devices without a bluez card (mice, keyboards)
    function codecsOf(dev: var): var {
        return (byAddress[dev?.address ?? ""]?.codecs ?? []).map(c => c.description);
    }

    // index into codecsOf(dev) of the active codec, -1 when unknown
    function codecIndex(dev: var): int {
        const info = byAddress[dev?.address ?? ""];
        if (!info || info.codec === null || info.codec === undefined)
            return -1;
        return info.codecs.findIndex(c => c.name === info.codec);
    }

    function setCodec(dev: var, index: int): void {
        const info = byAddress[dev?.address ?? ""];
        // two switches racing on one card leave PipeWire mid-renegotiation
        if (!info || index < 0 || index >= info.codecs.length || busyAddress !== "")
            return;
        if (info.codecs[index].name === info.codec)
            return;
        busyAddress = dev.address;
        switchProc.command = ["pactl", "send-message", cardOf(dev.address), "switch-codec", JSON.stringify(info.codecs[index].name)];
        switchProc.running = true;
    }

    function cardOf(address: string): string {
        return `/card/bluez_card.${address.replace(/:/g, "_")}/bluez`;
    }

    // one line per address: address, get-codec, list-codecs, tab separated.
    // A device without a card leaves the last two fields empty.
    function refresh(): void {
        if (!polling || queryProc.running)
            return;
        queryProc.command = ["sh", "-c", 'for a in "$@"; do c="/card/bluez_card.$(printf %s "$a" | tr : _)/bluez"; printf "%s\\t%s\\t%s\\n" "$a" "$(pactl send-message "$c" get-codec 2>/dev/null)" "$(pactl send-message "$c" list-codecs 2>/dev/null)"; done', "bt-codecs", ...addresses];
        queryProc.running = true;
    }

    function parse(text: string): void {
        const next = {};
        for (const line of text.split("\n")) {
            const [address, codec, codecs] = line.split("\t");
            // no card, or pactl failed
            if (!address || !codecs)
                continue;
            try {
                next[address] = {
                    codec: JSON.parse(codec || "null"),
                    codecs: JSON.parse(codecs)
                };
            } catch (e) {
                // half-written output: keep the row codec-less this round
            }
        }
        byAddress = next;
    }

    Process {
        id: queryProc

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Process {
        id: switchProc
        // pactl returns as soon as the message is answered; the node is
        // recreated a moment later and the nodes watcher below re-polls then
        onRunningChanged: {
            if (running)
                return;
            root.busyAddress = "";
            root.refresh();
        }
    }

    onPollingChanged: {
        if (polling)
            refresh();
        else
            byAddress = {};
    }
    onAddressesChanged: if (polling) refresh()

    Timer {
        interval: 5000
        running: root.polling
        repeat: true
        onTriggered: root.refresh()
    }

    // a codec switch tears the sink node down and rebuilds it, which lands
    // here twice in quick succession; one refresh after the dust settles
    Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void {
            if (root.polling)
                settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }
}
