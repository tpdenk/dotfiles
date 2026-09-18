pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property list<color> activeBorderStops
    property color inactiveBorder
    property int borderSize

    readonly property color activeBorder: activeBorderStops.length ? activeBorderStops[0] : "transparent"
    readonly property color activeBorderEnd: activeBorderStops.length ? activeBorderStops[activeBorderStops.length - 1] : "transparent"

    function stops(gradient: string): list<color> {
        const parts = gradient.split(" ");
        parts.pop(); // trailing angle
        return parts.map(p => Qt.color("#" + p));
    }

    Process {
        id: query
        running: true
        command: ["hyprctl", "-j", "--batch", "getoption general:col.active_border;" + "getoption general:col.inactive_border;" + "getoption general:border_size"]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const opt = JSON.parse(line);
                    switch (opt.option) {
                    case "general:col.active_border":
                        root.activeBorderStops = root.stops(opt.gradient);
                        break;
                    case "general:col.inactive_border":
                        root.inactiveBorder = root.stops(opt.gradient)[0];
                        break;
                    case "general:border_size":
                        root.borderSize = opt.int;
                        break;
                    }
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                query.running = true;
        }
    }
}
