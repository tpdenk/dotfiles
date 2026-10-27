pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// The todo window: a floating toplevel Hyprland centres and lets you drag
// (SUPER + drag), opened by `Panels.toggle("notes")` like the dropdowns.
// Enter files what is typed, Shift+Enter breaks the line; a click on a note
// opens it for editing, and every keystroke there lands on disk.
FloatingWindow { // qmllint disable uncreatable-type
    id: win

    title: "Notes"
    visible: false
    implicitWidth: 720
    implicitHeight: 640
    color: Theme.background

    // which note sits open under its row
    property string expandedPath: ""
    // deferred: the closing editor still holds focus until its loader drops it
    onExpandedPathChanged: if (expandedPath === "")
        Qt.callLater(() => input.forceActiveFocus())

    // "<category>: <verb> <noun>", drawn fresh on every open
    property string prompt: ""

    FileView {
        id: verbs
        path: Quickshell.shellDir + "/notes/verbs.txt"
        blockLoading: true
    }
    FileView {
        id: nouns
        path: Quickshell.shellDir + "/notes/nouns.txt"
        blockLoading: true
    }

    function pick(words: var): string {
        return words[Math.floor(Math.random() * words.length)];
    }

    // group headers between the notes, only for groups that have any. Rows
    // are keyed by path and group: ScriptModel moves a row with its old data
    // and drops its focus, so a group change rebuilds the row instead
    readonly property var rows: {
        const rows = [];
        for (const group of NotesStatus.groups) {
            const members = NotesStatus.notes.filter(note => note.group === group);
            if (members.length === 0)
                continue;
            rows.push({
                key: "#" + group,
                path: "#" + group,
                header: group
            });
            rows.push(...members.map(note => Object.assign({
                        key: note.path + "#" + group
                    }, note)));
        }
        return rows;
    }

    Connections {
        target: Panels
        function onOpenChanged(): void {
            win.visible = Panels.open === "notes";
        }
    }

    onVisibleChanged: {
        if (visible) {
            expandedPath = "";
            prompt = `${pick(NotesStatus.categories)}: ${pick(verbs.text().trim().split("\n"))} ${pick(nouns.text().trim().split("\n"))}`;
            input.forceActiveFocus();
        } else {
            Panels.close("notes");
        }
    }

    Shortcut {
        sequences: ["Escape"]
        onActivated: Panels.close("notes")
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            width: parent.width
            height: input.implicitHeight + 24
            radius: Theme.roundingSmall
            color: Theme.base

            Text {
                anchors.fill: input
                visible: input.text === ""
                text: win.prompt
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.muted
            }

            TextEdit {
                id: input
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 12
                }
                wrapMode: TextEdit.Wrap
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.brightText
                selectionColor: Qt.alpha(Theme.accent, 0.4)

                Keys.onPressed: event => {
                    if ((event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) || (event.modifiers & Qt.ShiftModifier))
                        return;
                    NotesStatus.add(input.text);
                    input.text = "";
                    event.accepted = true;
                }
            }
        }

        ListView {
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            model: ScriptModel {
                values: win.rows
                objectProp: "key"
            }

            delegate: Column {
                id: row
                required property var modelData

                readonly property bool isHeader: !!row.modelData.header
                readonly property bool expanded: win.expandedPath === row.modelData.path

                width: ListView.view.width

                Text {
                    visible: row.isHeader
                    topPadding: 12
                    bottomPadding: 4
                    text: row.modelData.header ?? ""
                    font.family: Theme.fontFamily
                    font.pointSize: Theme.smallSize
                    font.capitalization: Font.AllUppercase
                    color: Theme.muted
                }

                Rectangle {
                    visible: !row.isHeader
                    width: parent.width
                    height: 32
                    radius: Theme.roundingSmall
                    color: row.expanded ? Theme.highlight : hover.containsMouse ? Theme.base : "transparent"

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.expandedPath = row.expanded ? "" : row.modelData.path
                    }

                    Text {
                        id: tick
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: String.fromCodePoint(row.modelData.done ? 0xf0135 : 0xf0131)
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.h2Size
                        color: row.modelData.done ? Theme.success : Theme.muted

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotesStatus.save(row.modelData.path, {
                                done: !row.modelData.done
                            })
                        }
                    }

                    Text {
                        anchors {
                            left: tick.right
                            leftMargin: 10
                            right: parent.right
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: row.modelData.title ?? ""
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.strikeout: row.modelData.done ?? false
                        color: row.modelData.done ? Theme.muted : Theme.text
                    }
                }

                Loader {
                    active: row.expanded
                    // an unloaded Loader keeps its last implicit height;
                    // Column skips hidden children
                    visible: active
                    width: parent.width
                    // deferred: a row the list has just built has no window yet
                    onLoaded: Qt.callLater(() => item?.editor.forceActiveFocus())

                    sourceComponent: Column {
                        property alias editor: editor
                        padding: 8
                        leftPadding: 34
                        spacing: 8

                        Segmented {
                            options: NotesStatus.categories
                            current: NotesStatus.categories.indexOf(row.modelData.category)
                            onSelected: index => NotesStatus.save(row.modelData.path, {
                                category: NotesStatus.categories[index]
                            })
                        }

                        TextEdit {
                            id: editor
                            width: parent.width - parent.leftPadding - parent.padding
                            wrapMode: TextEdit.Wrap
                            font.family: Theme.fontFamily
                            font.pointSize: Theme.fontSize
                            color: Theme.text
                            selectionColor: Qt.alpha(Theme.accent, 0.4)
                            // set one time: a binding would snap back under
                            // the cursor on every save
                            Component.onCompleted: {
                                text = row.modelData.body;
                                cursorPosition = length;
                            }
                            onTextChanged: NotesStatus.save(row.modelData.path, {
                                body: text
                            })
                        }
                    }
                }
            }
        }
    }
}
