import qs
import qs.widgets

Pill {
    readonly property bool shown: ScreenShareStatus.active
    visible: shown
    bare: true
    interactive: false

    color: Theme.alert
    glyph: String.fromCodePoint(0xf13b4) // monitor-eye
    glyphColor: Theme.background
}
