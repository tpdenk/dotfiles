pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs

Scope {
    id: root

    function matches(query: string): list<var> {
        const q = query.toLowerCase();
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && e.name.toLowerCase().includes(q)).sort((a, b) => a.name.localeCompare(b.name));
    }

    function launch(entry: var): void {
        if (!entry)
            return;
        // DesktopEntry.execute() ignores Terminal=true (quickshell 0.3.1)
        if (entry.runInTerminal)
            Quickshell.execDetached(["xdg-terminal-exec", ...entry.command]);
        else
            entry.execute();
        win.visible = false;
    }

    PanelWindow { // qmllint disable uncreatable-type
        id: win
        visible: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "launcher"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        // no anchors -> centered on screen
        implicitWidth: 560
        implicitHeight: 400
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                input.text = "";
                input.forceActiveFocus();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: HyprColors.shadow
            border.width: HyprColors.borderSize
            border.color: HyprColors.activeBorder

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                TextInput {
                    id: input
                    width: parent.width
                    font.pixelSize: 18
                    color: "#c0caf5"
                    focus: true

                    onTextChanged: list.currentIndex = 0
                    onAccepted: root.launch(list.model[list.currentIndex])
                    Keys.onEscapePressed: win.visible = false
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()

                    Text {
                        anchors.fill: parent
                        visible: !input.text
                        text: "run..."
                        font: input.font
                        color: "#565f89"
                    }
                }

                ListView {
                    id: list
                    width: parent.width
                    height: parent.height - input.height - parent.spacing
                    clip: true
                    model: root.matches(input.text)
                    highlightMoveDuration: 0
                    highlight: Rectangle {
                        radius: 4
                        color: Qt.alpha(HyprColors.activeBorder, 0.25)
                    }

                    delegate: Text {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        padding: 6
                        text: modelData.name
                        font.pixelSize: 15
                        color: "#c0caf5"

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.launch(parent.modelData)
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            win.visible = !win.visible;
        }
        function open(): void {
            win.visible = true;
        }
        function close(): void {
            win.visible = false;
        }
    }
}
