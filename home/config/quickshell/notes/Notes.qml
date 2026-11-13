pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.widgets

// The todo window: a floating toplevel Hyprland centres and lets you drag
// (SUPER + drag), opened by `Panels.toggle("notes")` like the dropdowns.
// Enter files what is typed, Shift+Enter breaks the line; a click on a note
// opens it for editing, and every keystroke there lands on disk. A note drags
// up and down its category. Links open in the browser: a click in a title,
// Ctrl+click in the editor.
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

    // the note being dragged up or down its group, and how far
    property string dragPath: ""
    property real dragOffset: 0
    // cleared before `dragPath` on a drop, so the rows snap into the new order
    // instead of sliding there a second time
    property bool dragging: false
    readonly property int rowHeight: 32
    readonly property real rowStep: rowHeight + list.spacing
    readonly property string dragGroup: NotesStatus.notes.find(note => note.path === dragPath)?.group ?? ""
    readonly property var dragMembers: NotesStatus.notes.filter(note => note.group === dragGroup)
    readonly property int dragFrom: dragMembers.findIndex(note => note.path === dragPath)
    readonly property int dragTo: dragFrom + Math.round(dragOffset / rowStep)
    // the slots assume closed rows, so the group of the open note stays put
    readonly property string expandedGroup: NotesStatus.notes.find(note => note.path === expandedPath)?.group ?? ""

    function drag(path: string, offset: real): void {
        dragPath = path;
        dragging = true;
        // the note stays inside its group
        dragOffset = Math.max(-dragFrom * rowStep, Math.min((dragMembers.length - 1 - dragFrom) * rowStep, offset));
    }

    function drop(commit: bool): void {
        if (commit && dragTo !== dragFrom)
            NotesStatus.move(dragGroup, dragFrom, dragTo);
        dragging = false;
        dragPath = "";
        dragOffset = 0;
    }

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
            id: list
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
                readonly property bool dragged: win.dragPath === row.modelData.path
                readonly property bool draggable: !row.isHeader && row.modelData.group !== "done" && row.modelData.group !== win.expandedGroup
                // out of its slot: under the pointer, or making room for the
                // dragged note
                readonly property real shift: {
                    if (row.dragged)
                        return win.dragOffset;
                    const at = win.dragMembers.findIndex(note => note.path === row.modelData.path);
                    if (win.dragFrom < at && at <= win.dragTo)
                        return -win.rowStep;
                    if (win.dragTo <= at && at < win.dragFrom)
                        return win.rowStep;
                    return 0;
                }

                width: ListView.view.width
                z: row.dragged ? 1 : 0
                transform: Translate {
                    y: row.shift

                    Behavior on y {
                        enabled: win.dragging && !row.dragged

                        NumberAnimation {
                            duration: Theme.durationIn
                            easing.type: Easing.OutCubic
                        }
                    }
                }

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
                    height: win.rowHeight
                    radius: Theme.roundingSmall
                    color: row.expanded || row.dragged ? Theme.highlight : hover.containsMouse ? Theme.base : "transparent"

                    MouseArea {
                        id: hover

                        // pointer in list content coordinates at the press,
                        // which the row's own translation leaves alone
                        property real pressY
                        property bool moved

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: row.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        // the list would flick instead
                        preventStealing: true

                        onPressed: mouse => {
                            pressY = mapToItem(list.contentItem, 0, mouse.y).y;
                            moved = false;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || !row.draggable)
                                return;
                            const offset = mapToItem(list.contentItem, 0, mouse.y).y - pressY;
                            if (!moved && Math.abs(offset) < Qt.styleHints.startDragDistance)
                                return;
                            moved = true;
                            win.drag(row.modelData.path, offset);
                        }
                        onReleased: if (moved)
                            win.drop(true)
                        onCanceled: if (moved)
                            win.drop(false)
                        // a release after a drag still clicks
                        onClicked: if (!moved)
                            win.expandedPath = row.expanded ? "" : row.modelData.path
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
                            right: refs.left
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: NotesStatus.linkify(row.modelData.title ?? "")
                        textFormat: Text.StyledText
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pointSize: Theme.fontSize
                        font.strikeout: row.modelData.done ?? false
                        color: row.modelData.done ? Theme.muted : Theme.text
                        linkColor: Theme.accent
                        // a press off a link falls through to the row
                        onLinkActivated: link => NotesStatus.open(link)
                    }

                    Row {
                        id: refs
                        anchors {
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 4

                        Repeater {
                            model: row.modelData.refs ?? []

                            Pill {
                                id: pill
                                required property var modelData
                                label: pill.modelData.label
                                labelColor: pill.modelData.issue ? Theme.success : Theme.accentSecondary
                                onClicked: NotesStatus.open(pill.modelData.url)
                            }
                        }
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

                            HoverHandler {
                                id: linkHover
                                acceptedModifiers: Qt.ControlModifier
                                cursorShape: NotesStatus.linkAt(editor.text, editor.positionAt(linkHover.point.position.x, linkHover.point.position.y)) !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                            }

                            TapHandler {
                                acceptedModifiers: Qt.ControlModifier
                                onTapped: eventPoint => {
                                    const link = NotesStatus.linkAt(editor.text, editor.positionAt(eventPoint.position.x, eventPoint.position.y));
                                    if (link !== "")
                                        NotesStatus.open(link);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
