pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs
import qs.notifications
import qs.screenrecord
import qs.screenshot
import qs.session

Scope {
    id: root

    readonly property var modes: [
        {
            prefix: "=",
            label: "calc"
        },
        {
            prefix: "@",
            label: "windows"
        },
        {
            prefix: ":",
            label: "commands"
        },
        {
            prefix: "/",
            label: "files"
        },
        {
            prefix: ">",
            label: "run"
        }
    ]

    readonly property string home: Quickshell.env("HOME")

    property string mode: ""
    readonly property string query: input.text.trim()

    property var files: []

    readonly property var results: {
        switch (root.mode) {
        case "=":
            return calc(root.query);
        case "@":
            return windows(root.query);
        case ":":
            return commands(root.query);
        case "/":
            return root.files;
        case ">":
            return run(root.query);
        default:
            return apps(root.query);
        }
    }

    function open(): void {
        win.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        win.visible = true;
    }

    function close(): void {
        win.visible = false;
    }

    function activate(item: var): void {
        if (!item)
            return;
        if (item.key)
            Frecency.record(item.key);
        close();
        item.run();
    }

    function terminal(args: var): void {
        Quickshell.execDetached(["xdg-terminal-exec", "--"].concat(args));
    }

    function apps(q: string): var {
        const needle = q.toLowerCase();
        const scored = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue;
            const name = e.name.toLowerCase();
            const generic = (e.genericName ?? "").toLowerCase();
            let match = 0;
            if (needle === "")
                match = 1;
            else if (name.startsWith(needle))
                match = 3;
            else if (name.split(/[\s\-_.]/).some(w => w.startsWith(needle)))
                match = 2;
            else if (name.includes(needle) || generic.includes(needle))
                match = 1;
            if (match === 0)
                continue;
            const key = "app:" + e.id;
            scored.push({
                entry: e,
                key: key,
                rank: match * 100 + Frecency.score(key)
            });
        }
        scored.sort((a, b) => b.rank - a.rank || a.entry.name.localeCompare(b.entry.name));
        return scored.slice(0, 50).map(s => ({
                    key: s.key,
                    kind: "app",
                    title: s.entry.name,
                    detail: s.entry.genericName ?? "",
                    hint: "open",
                    run: () => {
                        // DesktopEntry.execute() ignores Terminal=true (quickshell 0.3.1)
                        if (s.entry.runInTerminal)
                            Quickshell.execDetached(["xdg-terminal-exec", ...s.entry.command]);
                        else
                            s.entry.execute();
                    }
                }));
    }

    readonly property var mathNames: ({
            pi: "Math.PI",
            e: "Math.E",
            sqrt: "Math.sqrt",
            cbrt: "Math.cbrt",
            abs: "Math.abs",
            round: "Math.round",
            floor: "Math.floor",
            ceil: "Math.ceil",
            min: "Math.min",
            max: "Math.max",
            pow: "Math.pow",
            sin: "Math.sin",
            cos: "Math.cos",
            tan: "Math.tan",
            asin: "Math.asin",
            acos: "Math.acos",
            atan: "Math.atan",
            ln: "Math.log",
            log: "Math.log10",
            log2: "Math.log2",
            exp: "Math.exp"
        })

    function evaluate(q: string): var {
        if (q === "" || !/^[0-9a-z\s+\-*/%^().,_]*$/i.test(q))
            return null;
        let unknown = false;
        const js = q.replace(/\^/g, "**").replace(/_/g, "").replace(/[a-z][a-z0-9]*/gi, w => {
            const m = root.mathNames[w.toLowerCase()];
            if (!m)
                unknown = true;
            return m ?? "";
        });
        if (unknown)
            return null;
        try {
            const v = Function(`"use strict"; return (${js});`)();
            return typeof v === "number" && isFinite(v) ? v : null;
        } catch (e) {
            return null;
        }
    }

    function calc(q: string): var {
        const v = evaluate(q);
        if (v === null)
            return q === "" ? [] : [
                {
                    kind: "calc",
                    title: "…",
                    detail: "not an expression",
                    hint: "",
                    run: () => {}
                }
            ];
        const text = String(Number.isInteger(v) ? v : Number(v.toPrecision(12)));
        return [
            {
                kind: "calc",
                title: text,
                detail: q,
                hint: "copy",
                run: () => Clipboard.copy(text)
            }
        ];
    }

    function windows(q: string): var {
        const needle = q.toLowerCase();
        return ToplevelManager.toplevels.values.filter(t => needle === "" || (t.title ?? "").toLowerCase().includes(needle) || (t.appId ?? "").toLowerCase().includes(needle)).map(t => ({
                    kind: "window",
                    title: t.title || t.appId,
                    detail: t.appId,
                    hint: "focus",
                    run: () => t.activate()
                }));
    }

    readonly property var panelNames: ["network", "bluetooth", "audio", "power", "updates", "docker", "tailscale", "notifications", "calendar"]

    function commands(q: string): var {
        const all = [
            {
                id: "lock",
                title: "Lock",
                run: () => Quickshell.execDetached(["loginctl", "lock-session"])
            },
            {
                id: "session",
                title: "Session menu…",
                run: () => Session.show()
            },
            {
                id: "suspend",
                title: "Suspend",
                run: () => Quickshell.execDetached(["systemctl", "suspend"])
            },
            {
                id: "logout",
                title: "Log out",
                run: () => Session.show("logout")
            },
            {
                id: "reboot",
                title: "Reboot",
                run: () => Session.show("reboot")
            },
            {
                id: "shutdown",
                title: "Shut down",
                run: () => Session.show("shutdown")
            },
            {
                id: "dnd",
                title: NotificationCenter.dnd ? "Do not disturb: turn off" : "Do not disturb: turn on",
                run: () => NotificationCenter.dnd = !NotificationCenter.dnd
            },
            {
                id: "clear",
                title: "Clear notifications",
                run: () => NotificationCenter.clear()
            },
            {
                id: "screenshot",
                title: "Screenshot",
                run: () => ScreenshotStatus.take()
            },
            {
                id: "record",
                title: "Record screen",
                run: () => ScreenRecordStatus.start()
            },
            {
                id: "reload",
                title: "Reload shell",
                run: () => Quickshell.reload(false)
            }
        ].concat(root.panelNames.map(name => ({
                    id: "panel-" + name,
                    title: `Open ${name}`,
                    run: () => Panels.toggle(name)
                })));
        const needle = q.toLowerCase();
        return all.filter(c => needle === "" || c.title.toLowerCase().includes(needle) || c.id.includes(needle)).map(c => ({
                    key: "cmd:" + c.id,
                    kind: "command",
                    title: c.title,
                    detail: "",
                    hint: "run",
                    run: c.run,
                    rank: Frecency.score("cmd:" + c.id)
                })).sort((a, b) => needle === "" ? 0 : b.rank - a.rank);
    }

    Timer {
        id: fdDebounce
        interval: 120
        onTriggered: {
            fd.running = false;
            if (root.mode !== "/" || root.query === "") {
                root.files = [];
                return;
            }
            fd.command = ["fd", "--hidden", "--exclude", ".git", "--ignore-case", "--max-results", "40", "--absolute-path", "--", root.query, root.home];
            fd.running = true;
        }
    }

    onQueryChanged: {
        if (root.mode === "/")
            fdDebounce.restart();
    }
    onModeChanged: {
        if (root.mode === "/")
            fdDebounce.restart();
    }

    Process {
        id: fd
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(p => p !== "").map(path => {
                    const dir = path.endsWith("/");
                    const clean = dir ? path.slice(0, -1) : path;
                    const slash = clean.lastIndexOf("/");
                    return {
                        kind: dir ? "dir" : "file",
                        title: clean.slice(slash + 1),
                        detail: clean.slice(0, slash).replace(root.home, "~"),
                        hint: dir ? "lf" : "open",
                        run: () => dir ? root.terminal(["lf", clean]) : Quickshell.execDetached(["xdg-open", clean])
                    };
                });
            }
        }
    }

    function run(q: string): var {
        if (q === "")
            return [];
        return [
            {
                kind: "shell",
                title: q,
                detail: "in a terminal",
                hint: "run",
                run: () => root.terminal(["sh", "-c", `${q}; exec "\${SHELL:-sh}"`])
            }
        ];
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: win
        visible: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "launcher"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        margins.top: Math.round((win.screen?.height ?? 1000) * 0.22)
        implicitWidth: 640
        implicitHeight: body.implicitHeight
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                input.text = "";
                root.mode = "";
                root.files = [];
                list.currentIndex = 0;
                input.forceActiveFocus();
                card.opacity = 0;
                appear.restart();
            }
        }

        NumberAnimation {
            id: appear
            target: card
            property: "opacity"
            to: 1
            duration: Theme.durationIn
        }

        Column {
            id: body
            width: parent.width
            spacing: 8

            Rectangle {
                id: card
                width: parent.width
                height: inputRow.height + (list.count > 0 ? list.height + 9 : 0)
                radius: Theme.windowRounding
                color: Theme.background
                border.width: 1
                border.color: Theme.highlight
                clip: true

                Item {
                    id: inputRow
                    width: parent.width
                    height: 48

                    Text {
                        id: modeGlyph
                        anchors {
                            left: parent.left
                            leftMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        visible: root.mode !== ""
                        text: root.modes.find(m => m.prefix === root.mode)?.label ?? ""
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.smallSize
                        color: Theme.background

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -3
                            anchors.leftMargin: -6
                            anchors.rightMargin: -6
                            z: -1
                            radius: Theme.roundingSmall
                            color: Theme.accent
                        }
                    }

                    TextInput {
                        id: input
                        anchors {
                            left: root.mode !== "" ? modeGlyph.right : parent.left
                            leftMargin: root.mode !== "" ? 14 : 16
                            right: parent.right
                            rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.h3Size
                        color: Theme.brightText
                        selectionColor: Qt.alpha(Theme.accent, 0.4)
                        focus: true
                        clip: true

                        onTextChanged: {
                            if (root.mode === "" && text.length > 0 && root.modes.some(m => m.prefix === text[0])) {
                                root.mode = text[0];
                                text = text.slice(1);
                            }
                            list.currentIndex = 0;
                        }
                        onAccepted: root.activate(root.results[list.currentIndex])
                        Keys.onEscapePressed: {
                            if (input.text !== "")
                                input.text = "";
                            else if (root.mode !== "")
                                root.mode = "";
                            else
                                root.close();
                        }
                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onTabPressed: list.incrementCurrentIndex()
                        Keys.onBacktabPressed: list.decrementCurrentIndex()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Backspace && input.text === "" && root.mode !== "") {
                                root.mode = "";
                                event.accepted = true;
                                return;
                            }
                            if (!(event.modifiers & Qt.ControlModifier))
                                return;
                            if (event.key === Qt.Key_C) {
                                root.close();
                                event.accepted = true;
                                return;
                            }
                            if (event.key === Qt.Key_N || event.key === Qt.Key_J) {
                                list.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_P || event.key === Qt.Key_K) {
                                list.decrementCurrentIndex();
                                event.accepted = true;
                            }
                        }

                        Text {
                            anchors.fill: parent
                            visible: !input.text
                            text: root.mode === "" ? "search apps, or type a prefix…" : ({
                                    "=": "2^10 / 3",
                                    "@": "window title or app",
                                    ":": "lock, reboot, open network…",
                                    "/": "file or directory name",
                                    ">": "command to run"
                                })[root.mode]
                            font: input.font
                            color: Theme.muted
                        }
                    }
                }

                Rectangle {
                    anchors.top: inputRow.bottom
                    width: parent.width
                    height: 1
                    visible: list.count > 0
                    color: Theme.highlight
                }

                ListView {
                    id: list
                    anchors {
                        top: inputRow.bottom
                        topMargin: 5
                        left: parent.left
                        right: parent.right
                        margins: 4
                    }
                    height: Math.min(contentHeight, 8 * 34)
                    clip: true
                    model: root.results
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    keyNavigationWraps: true

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var modelData
                        readonly property bool current: ListView.isCurrentItem

                        width: ListView.view.width
                        height: 34
                        radius: Theme.roundingSmall
                        color: current ? Theme.base : rowMouse.containsMouse ? Qt.alpha(Theme.highlight, 0.6) : "transparent"

                        Rectangle {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            width: 2
                            height: parent.height - 12
                            radius: 1
                            visible: row.current
                            color: Theme.accent
                        }

                        Text {
                            id: title
                            anchors {
                                left: parent.left
                                leftMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            width: Math.min(implicitWidth, parent.width * 0.55)
                            text: row.modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            color: row.current ? Theme.brightText : Theme.text
                        }

                        Text {
                            anchors {
                                left: title.right
                                leftMargin: 10
                                right: kind.left
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            text: row.modelData.detail ?? ""
                            textFormat: Text.PlainText
                            elide: Text.ElideMiddle
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.smallSize
                            color: Theme.muted
                        }

                        Text {
                            id: kind
                            anchors {
                                right: hint.left
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            text: row.modelData.kind
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.smallSize
                            color: Theme.muted
                        }

                        Text {
                            id: hint
                            anchors {
                                right: parent.right
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            width: 64
                            horizontalAlignment: Text.AlignRight
                            text: row.modelData.hint ? `↵ ${row.modelData.hint}` : ""
                            opacity: row.current ? 1 : 0
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.smallSize
                            color: Theme.accent
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.activate(row.modelData)
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: hints.implicitWidth + 24
                implicitHeight: 24
                radius: height / 2
                color: Theme.background
                border.width: 1
                border.color: Theme.highlight

                Row {
                    id: hints
                    anchors.centerIn: parent
                    spacing: 16

                    Repeater {
                        model: root.modes

                        Text {
                            id: modeHint
                            required property var modelData
                            text: `${modelData.prefix} ${modelData.label}`
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.smallSize
                            color: root.mode === modelData.prefix ? Theme.accent : hintMouse.containsMouse ? Theme.text : Theme.muted

                            MouseArea {
                                id: hintMouse
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.mode = root.mode === modeHint.modelData.prefix ? "" : modeHint.modelData.prefix;
                                    input.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (win.visible)
                root.close();
            else
                root.open();
        }
    }
}
