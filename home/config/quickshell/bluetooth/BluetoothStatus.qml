pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import qs

// State of the machine's bluetooth controller and the devices around it:
// BlueZ facts from Quickshell.Bluetooth, plus the discoverability and scanning
// the panel turns on for as long as it is open.
Singleton {
    id: root

    // whether the details panel is open; visibility and scanning both follow
    // it
    readonly property bool expanded: Panels.open === "bluetooth"

    // the controller the bar icon speaks for. A second adapter would need a
    // tab strip like the network panel's; this machine has one.
    readonly property var adapter: Bluetooth.defaultAdapter

    readonly property bool present: !!adapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property string adapterName: adapter?.name ?? ""
    readonly property string status: adapter ? BluetoothAdapterState.toString(adapter.state) : "No adapter"
    readonly property bool discoverable: adapter?.discoverable ?? false
    readonly property bool scanning: adapter?.discovering ?? false

    // --- devices ---

    // connected first, then anything with a name, then paired, then by label:
    // a row showing a bare address says nothing useful, so it never sits above
    // a device that introduced itself. Sorting on anything that moves while a
    // scan runs would reshuffle the list under the cursor.
    readonly property var devices: (adapter?.devices?.values ?? []).slice().sort((a, b) => {
        if (a.connected !== b.connected)
            return a.connected ? -1 : 1;
        if ((nameOf(a) !== "") !== (nameOf(b) !== ""))
            return nameOf(a) !== "" ? -1 : 1;
        if (a.paired !== b.paired)
            return a.paired ? -1 : 1;
        return label(a).localeCompare(label(b));
    })

    // BlueZ's alias falls back to the address with its colons swapped for
    // dashes, so a device that never introduced itself would otherwise look
    // named. An alias someone typed themselves still wins over the
    // advertised name.
    function nameOf(dev: var): string {
        if (!dev)
            return "";
        const alias = dev.name === dev.address.replace(/:/g, "-") ? "" : dev.name;
        return alias || dev.deviceName || "";
    }

    readonly property int connectedCount: devices.filter(d => d.connected).length

    // the name when there is one, the address when there is not
    function label(dev: var): string {
        return dev ? nameOf(dev) || dev.address || "" : "";
    }

    // what the row is doing right now, if anything. A device sitting
    // disconnected says only whether it is known to us.
    function stateLabel(dev: var): string {
        if (!dev)
            return "";
        if (dev.pairing)
            return "pairing…";
        if (dev.state !== BluetoothDeviceState.Disconnected)
            return BluetoothDeviceState.toString(dev.state).toLowerCase();
        return dev.paired ? "paired" : "";
    }

    function setEnabled(on: bool): void {
        if (adapter)
            adapter.enabled = on;
    }

    // one click does the obvious next thing for the row's state. BlueZ's
    // system agent answers any PIN or passkey prompt, so pairing needs no
    // input from us.
    function activate(dev: var): void {
        if (!dev)
            return;
        if (dev.pairing)
            dev.cancelPair();
        else if (dev.connected)
            dev.disconnect();
        else if (!dev.paired)
            dev.pair();
        else
            dev.connect();
    }

    // --- the bar icon ---

    readonly property string icon: String.fromCodePoint(!present || !enabled ? 0xf00b2 : connectedCount > 0 ? 0xf00b1 : 0xf00af) // bluetooth off, bluetooth connect, bluetooth

    // what the controller is doing, in the width of a bar pill: the device on
    // the other end when there is exactly one, a count when there are more
    readonly property string barLabel: {
        if (!present)
            return "None";
        if (!enabled)
            return "Off";
        const connected = devices.filter(d => d.connected);
        if (connected.length === 1)
            return label(connected[0]);
        if (connected.length > 1)
            return `${connected.length} devices`;
        return "On";
    }

    // --- visibility and scanning: only while the dialog is on screen ---

    // the dialog's lifetime is the visibility window, so the timeouts are 0
    // ("never expire") and closing the panel is what ends it. Both settings
    // are handed over in one place, so a vanishing adapter or a closing panel
    // always gets them undone.
    readonly property var sessionAdapter: expanded && enabled ? adapter : null
    property var activeAdapter: null

    onSessionAdapterChanged: {
        if (activeAdapter === sessionAdapter)
            return;
        endSession();
        activeAdapter = sessionAdapter;
        if (activeAdapter) {
            activeAdapter.discoverableTimeout = 0;
            activeAdapter.pairableTimeout = 0;
            activeAdapter.discoverable = true;
            activeAdapter.pairable = true;
            activeAdapter.discovering = true;
        }
    }

    function endSession(): void {
        if (!activeAdapter)
            return;
        activeAdapter.discovering = false;
        activeAdapter.discoverable = false;
        activeAdapter.pairable = false;
        activeAdapter = null;
    }

    // BlueZ keeps `discoverable` set on its own, and a reload or a crash
    // destroys this singleton without running any hook, so a shell that went
    // away with the dialog open would leave the machine visible for good.
    // Nothing else here ever turns it on, so a controller found discoverable
    // with the dialog closed is a leftover of ours to undo.
    Component.onCompleted: dropStaleSession()
    onAdapterChanged: dropStaleSession()

    function dropStaleSession(): void {
        if (sessionAdapter || !adapter?.discoverable)
            return;
        adapter.discoverable = false;
        adapter.pairable = false;
        adapter.discovering = false;
    }
}
