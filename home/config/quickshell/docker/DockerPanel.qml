import QtQuick
import qs
import qs.widgets

// The docker card: how much is up, and the containers themselves.
PanelCard {
    title: "Docker"

    Stat {
        width: parent.width
        label: "Running"
        value: DockerStatus.available ? `${DockerStatus.count}` : "unknown"
    }

    Stat {
        width: parent.width
        label: "Stopped"
        value: DockerStatus.available ? `${DockerStatus.stopped}` : "unknown"
    }

    Stat {
        width: parent.width
        visible: DockerStatus.projects > 0
        label: "Compose projects"
        value: `${DockerStatus.projects}`
    }

    Text {
        width: parent.width
        visible: !DockerStatus.available
        text: "The docker daemon is not answering"
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pointSize: Theme.smallSize
        color: Theme.accentSecondary
    }

    Divider {
        width: parent.width
    }

    DockerContainers {
        width: parent.width
    }
}
