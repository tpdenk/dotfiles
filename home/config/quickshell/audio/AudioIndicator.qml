import qs
import qs.widgets

// Bar pill for the default output: its icon and volume. Click toggles the
// details panel.
Pill {
    glyph: AudioStatus.icon
    // muted still shows the level it would return to
    label: AudioStatus.percent(AudioStatus.sink)
    highlight: Panels.open === "audio"
    glyphColor: AudioStatus.muted ? Theme.muted : Theme.accent
    labelColor: AudioStatus.muted ? Theme.muted : Theme.text

    onClicked: Panels.toggle("audio")
}
