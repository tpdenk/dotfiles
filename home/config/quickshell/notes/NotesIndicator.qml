import qs
import qs.widgets

// Bar pill for the todo list: how many notes sit under "Now". Click opens the
// notes window.
Pill {
    bare: true
    glyph: String.fromCodePoint(0xf0756) // format-list-checks
    label: NotesStatus.nowCount > 0 ? String(NotesStatus.nowCount) : ""
    labelColor: Theme.brightText
    highlight: Panels.open === "notes"

    onClicked: Panels.toggle("notes")
}
