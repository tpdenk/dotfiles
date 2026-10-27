pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

// The todo list: one markdown file per note under ~/.notes. YAML front matter
// holds the category, the done flag and the creation time; the body is the
// text as typed, its first line the title. Every file is watched, so an edit
// from another program shows up too.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.notes"
    readonly property var categories: ["now", "next", "later", "maybe"]
    // list order; a done note sits in "done" whatever its category
    readonly property var groups: ["now", "next", "later", "maybe", "done"]

    property var notes: []
    readonly property int nowCount: notes.filter(note => note.group === "now").length

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: ["*.md"]
        showDirs: false
    }

    Instantiator {
        id: files
        model: folder

        delegate: FileView {
            required property string filePath
            path: filePath
            watchChanges: true
            onFileChanged: reload()
            onLoaded: root.refresh()
            onTextChanged: root.refresh()
        }

        onObjectRemoved: root.refresh()
    }

    // the file of a note not yet on disk; the folder model picks it up once
    // written
    FileView {
        id: writer
        printErrors: false
    }

    function refresh(): void {
        const list = [];
        for (let i = 0; i < files.count; i++) {
            const file = files.objectAt(i);
            if (file.loaded)
                list.push(root.parse(file.path, file.text()));
        }
        list.sort((a, b) => root.groups.indexOf(a.group) - root.groups.indexOf(b.group) || a.created.localeCompare(b.created));
        root.notes = list;
    }

    function parse(path: string, text: string): var {
        const m = text.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
        const meta = {};
        for (const line of (m ? m[1] : "").split("\n")) {
            const colon = line.indexOf(":");
            if (colon > 0)
                meta[line.slice(0, colon).trim()] = line.slice(colon + 1).trim();
        }
        const body = m ? m[2] : text;
        const done = meta.done === "true";
        const category = root.categories.includes(meta.category) ? meta.category : "next";
        return {
            path: path,
            category: category,
            done: done,
            group: done ? "done" : category,
            created: meta.created ?? "",
            body: body,
            title: body.split("\n")[0]
        };
    }

    function serialize(note: var): string {
        return `---\ncategory: ${note.category}\ndone: ${note.done}\ncreated: ${note.created}\n---\n${note.body}`;
    }

    // `later: fix the roof` files under "later"; no prefix means "next"
    function add(text: string): void {
        let body = text.trim();
        const prefix = body.match(/^(now|next|later|maybe):\s*/i);
        const category = prefix ? prefix[1].toLowerCase() : "next";
        if (prefix)
            body = body.slice(prefix[0].length);
        if (body === "")
            return;
        const created = Qt.formatDateTime(new Date(), "yyyy-MM-ddTHH:mm:ss.zzz");
        writer.path = `${root.dir}/${created.replace(/[:.]/g, "-")}.md`;
        writer.setText(root.serialize({
            category: category,
            done: false,
            created: created,
            body: body
        }));
    }

    function save(path: string, patch: var): void {
        const note = root.notes.find(entry => entry.path === path);
        for (let i = 0; i < files.count; i++) {
            const file = files.objectAt(i);
            if (file.path === path)
                file.setText(root.serialize(Object.assign({}, note, patch)));
        }
    }
}
