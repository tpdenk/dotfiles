import qs
import qs.widgets

Pill {
    visible: DockerStatus.available

    glyph: DockerStatus.icon
    label: DockerStatus.label
    labelColor: Theme.brightText
}
