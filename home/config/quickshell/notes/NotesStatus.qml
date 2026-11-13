pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel

// The todo list: one markdown file per note under ~/.notes. YAML front matter
// holds the category, the done flag, the creation time and, once dragged, the
// rank in the category; the body is the text as typed, its first line the
// title. Every file is watched, so an edit from another program shows up too.
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
            // a write updates the text at once: the rows of a drop take their
            // new order in one go, not one file at a time
            blockWrites: true
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
        // ranked notes first, in rank order; NaN from two unranked ones falls
        // through to the creation time
        list.sort((a, b) => root.groups.indexOf(a.group) - root.groups.indexOf(b.group) || (a.rank ?? Infinity) - (b.rank ?? Infinity) || a.created.localeCompare(b.created));
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
            rank: /^\d+$/.test(meta.rank ?? "") ? parseInt(meta.rank) : null,
            body: body,
            title: body.split("\n")[0],
            refs: root.refs(root.links(body))
        };
    }

    // links as typed: with a scheme, from `www.`, or a bare `host.tld/path`;
    // trailing punctuation belongs to the sentence around the link
    function links(text: string): var {
        const pattern = /\b(?:https?:\/\/|www\.)[^\s<>"]+|\b(?:[a-z0-9-]+\.)+[a-z]{2,}\/[^\s<>"]*/gi;
        const found = [];
        let m;
        while ((m = pattern.exec(text)) !== null) {
            const link = m[0].replace(/[.,;:!?'")\]}]+$/, "");
            found.push({
                index: m.index,
                text: link,
                url: /^https?:\/\//i.test(link) ? link : "https://" + link
            });
        }
        return found;
    }

    // the link under `position` in `text`, or ""
    function linkAt(text: string, position: int): string {
        return root.links(text).find(link => position >= link.index && position < link.index + link.text.length)?.url ?? "";
    }

    // `github.com/<owner>/<repo>/issues/<n>` and `…/pull/<n>` links, one entry
    // per issue or pull request, the issues first
    function refs(links: var): var {
        const found = [];
        for (const link of links) {
            const m = link.url.match(/^https?:\/\/(?:www\.)?github\.com\/([\w.-]+)\/([\w.-]+)\/(issues?|pull)\/(\d+)/i);
            if (!m)
                continue;
            const issue = m[3].toLowerCase() !== "pull";
            const url = `https://github.com/${m[1]}/${m[2]}/${issue ? "issues" : "pull"}/${m[4]}`;
            if (!found.some(ref => ref.url === url))
                found.push({
                    issue: issue,
                    label: (issue ? "!" : "#") + m[4],
                    url: url
                });
        }
        return found.filter(ref => ref.issue).concat(found.filter(ref => !ref.issue));
    }

    // StyledText of `text`, escaped, every link an anchor
    function linkify(text: string): string {
        const escape = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
        let html = "";
        let at = 0;
        for (const link of root.links(text)) {
            html += escape(text.slice(at, link.index)) + `<a href="${escape(link.url)}">${escape(link.text)}</a>`;
            at = link.index + link.text.length;
        }
        return html + escape(text.slice(at));
    }

    // the browser opens beside the window, which stays up
    function open(url: string): void {
        Quickshell.execDetached(["xdg-open", url]);
    }

    // `rank` only once the note has been dragged in its category
    function serialize(note: var): string {
        const rank = note.rank === null || note.rank === undefined ? "" : `rank: ${note.rank}\n`;
        return `---\ncategory: ${note.category}\ndone: ${note.done}\ncreated: ${note.created}\n${rank}---\n${note.body}`;
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

    // a note moved to another category drops its rank there. A write that
    // changes nothing is skipped: the reload would rebuild the rows while the
    // editor sets its first text, inside the binding that opens it
    function save(path: string, patch: var): void {
        const note = root.notes.find(entry => entry.path === path);
        if (patch.category !== undefined && patch.category !== note.category)
            patch = Object.assign({
                rank: null
            }, patch);
        const text = root.serialize(Object.assign({}, note, patch));
        if (text === root.serialize(note))
            return;
        for (let i = 0; i < files.count; i++) {
            const file = files.objectAt(i);
            if (file.path === path)
                file.setText(text);
        }
    }

    // put the note at `from` among those of `group` at `to`, and rank them all
    function move(group: string, from: int, to: int): void {
        const members = root.notes.filter(note => note.group === group);
        members.splice(to, 0, members.splice(from, 1)[0]);
        members.forEach((note, rank) => {
            if (note.rank !== rank)
                root.save(note.path, {
                    rank: rank
                });
        });
    }
}
