import qs
import qs.widgets

// Bar pill for the docker engine: how many containers are up. Click toggles
// the container list.
Pill {
    readonly property bool shown: DockerStatus.available && (DockerStatus.count > 0 || Panels.statusExpanded || highlight)
    visible: shown
    bare: true

    glyph: DockerStatus.icon
    label: DockerStatus.label
    labelColor: Theme.brightText
    highlight: Panels.open === "docker"

    onClicked: Panels.toggle("docker")
}
