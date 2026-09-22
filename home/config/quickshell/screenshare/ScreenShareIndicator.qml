import qs
import qs.widgets

Pill {
    visible: ScreenShareStatus.active

    color: Theme.alert
    glyph: String.fromCodePoint(0xf13b4) // monitor-eye
    glyphColor: Theme.background
}
