import qs
import qs.widgets

// Bar pill for the docker engine: how many containers are up. Click toggles
// the container list.
Pill {
    visible: DockerStatus.available

    glyph: DockerStatus.icon
    label: DockerStatus.label
    labelColor: Theme.brightText
    highlight: DockerStatus.expanded

    onClicked: Panels.toggle("docker")
}
