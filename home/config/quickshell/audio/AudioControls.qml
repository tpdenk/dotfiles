import QtQuick
import qs
import qs.widgets

// One direction's controls: the default device's name with its mute switch,
// then its volume.
Column {
    id: root

    // the PipeWire node, null when the direction has no device
    required property var node
    required property string placeholder

    spacing: 6

    LabeledRow {
        width: parent.width
        label: AudioStatus.label(root.node) || root.placeholder

        // on means audible, so the switch is the inverse of the mute flag
        Toggle {
            anchors.verticalCenter: parent.verticalCenter
            enabled: !!root.node
            checked: !(root.node?.audio?.muted ?? true)
            onToggled: on => AudioStatus.setMuted(root.node, !on)
        }
    }

    LabeledRow {
        width: parent.width
        label: "Volume"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: AudioStatus.percent(root.node)
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.text
        }

        Slider {
            anchors.verticalCenter: parent.verticalCenter
            value: root.node?.audio?.volume ?? 0
            onMoved: v => AudioStatus.setVolume(root.node, v)
        }
    }
}
