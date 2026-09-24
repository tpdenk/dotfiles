import qs
import qs.widgets

Pill {
    readonly property bool shown: NotificationCenter.count > 0 || NotificationCenter.dnd || Panels.statusExpanded || highlight
    visible: shown
    bare: true

    glyph: NotificationCenter.icon
    label: NotificationCenter.count > 0 ? String(NotificationCenter.count) : ""
    highlight: Panels.open === "notifications"
    glyphColor: NotificationCenter.dnd ? Theme.muted : NotificationCenter.count > 0 ? Theme.accent : Theme.muted
    labelColor: Theme.brightText

    onClicked: Panels.toggle("notifications")
}
