pragma Singleton
import Quickshell
import QtQuick
import qs

// The Corsair Sabre v2 Pro's charge and whether it is charging, as
// `sabre_v2_pro` reads them over hidraw, wired or through its receiver.
Singleton {
    id: root

    readonly property string bin: (Quickshell.env("CARGO_HOME") || Quickshell.env("HOME") + "/.cargo") + "/bin/sabre_v2_pro"

    // false while the mouse is off, out of range, or unplugged along with its
    // receiver: the cli exits 1 for all of them
    property bool connected: false
    property int charge: 0
    property bool charging: false

    readonly property bool low: connected && !charging && charge <= 15

    readonly property string icon: String.fromCodePoint(0xf037d) // mouse
    readonly property string chargingIcon: String.fromCodePoint(0xf0241) // flash
    readonly property string label: `${charge}%`

    Poll {
        // one line each; the second query only runs once the first found the mouse
        command: ["sh", "-c", "\"$0\" battery && \"$0\" charging", root.bin]
        interval: 5000

        onFinished: text => {
            const [charge, charging] = text.trim().split("\n");
            root.charge = parseInt(charge) || 0;
            root.charging = charging === "1";
            root.connected = true;
        }
        onFailed: root.connected = false
    }
}
