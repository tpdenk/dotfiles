import Quickshell
import Quickshell.Wayland
import qs
import qs.widgets

// Bar pill that toggles the prevent-sleep hold. Each bar's copy inhibits
// through its own surface, so the hold outlives any one screen going away.
Pill {
    id: root

    glyph: String.fromCodePoint(IdleStatus.inhibited ? 0xf0176 : 0xf0fab) // coffee / coffee-off-outline
    glyphColor: IdleStatus.inhibited ? Theme.accent : Theme.muted
    highlight: IdleStatus.inhibited
    onClicked: IdleStatus.inhibited = !IdleStatus.inhibited

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: IdleStatus.inhibited
    }
}
