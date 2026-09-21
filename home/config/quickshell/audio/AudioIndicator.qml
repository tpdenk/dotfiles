import qs
import qs.widgets

// Bar pill for the default output: its icon and volume. Click toggles the
// details panel.
Pill {
    id: root

    glyph: AudioStatus.icon
    label: AudioStatus.volumeLabel
    highlight: AudioStatus.expanded
    glyphColor: AudioStatus.muted ? Theme.muted : Theme.accent
    labelColor: AudioStatus.muted ? Theme.muted : Theme.text

    onClicked: Panels.toggle("audio")
}
