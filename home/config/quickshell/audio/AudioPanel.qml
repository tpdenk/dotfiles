import QtQuick
import qs
import qs.widgets

// The audio details card: title, mute switches, volumes and device pickers.
PanelCard {
    title: "Audio"

    // the switch belongs to the default output, so it sits above that
    // device's own numbers
    Item {
        width: parent.width
        implicitHeight: Math.max(outputName.implicitHeight, outputToggle.implicitHeight)

        Text {
            id: outputName
            anchors {
                left: parent.left
                right: outputToggle.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: AudioStatus.label(AudioStatus.sink) || "No output"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }

        // on means audible, so the switch is the inverse of the mute flag
        Toggle {
            id: outputToggle
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            enabled: !!AudioStatus.sink
            checked: !AudioStatus.muted
            onToggled: on => AudioStatus.setMuted(AudioStatus.sink, !on)
        }
    }

    Divider {
        width: parent.width
    }

    Stat {
        width: parent.width
        label: "Output"
        value: AudioStatus.label(AudioStatus.sink) || "—"
    }

    Item {
        width: parent.width
        implicitHeight: Math.max(volumeLabel.implicitHeight, volumeRow.implicitHeight)

        Text {
            id: volumeLabel
            anchors.left: parent.left
            text: "Volume"
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }

        Row {
            id: volumeRow
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(AudioStatus.volume * 100)}%`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.text
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                value: AudioStatus.volume
                onMoved: v => AudioStatus.setVolume(AudioStatus.sink, v)
            }
        }
    }

    Divider {
        width: parent.width
    }

    // the same three rows again, for the microphone side
    Item {
        width: parent.width
        implicitHeight: Math.max(inputName.implicitHeight, inputToggle.implicitHeight)

        Text {
            id: inputName
            anchors {
                left: parent.left
                right: inputToggle.left
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: AudioStatus.label(AudioStatus.source) || "No input"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }

        Toggle {
            id: inputToggle
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            enabled: !!AudioStatus.source
            checked: !AudioStatus.inputMuted
            onToggled: on => AudioStatus.setMuted(AudioStatus.source, !on)
        }
    }

    Stat {
        width: parent.width
        label: "Input"
        value: AudioStatus.label(AudioStatus.source) || "—"
    }

    Item {
        width: parent.width
        implicitHeight: Math.max(inputVolumeLabel.implicitHeight, inputVolumeRow.implicitHeight)

        Text {
            id: inputVolumeLabel
            anchors.left: parent.left
            text: "Input volume"
            font.family: Theme.fontFamily
            font.pointSize: Theme.fontSize
            color: Theme.muted
        }

        Row {
            id: inputVolumeRow
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(AudioStatus.inputVolume * 100)}%`
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
                color: Theme.text
            }

            Slider {
                anchors.verticalCenter: parent.verticalCenter
                value: AudioStatus.inputVolume
                onMoved: v => AudioStatus.setVolume(AudioStatus.source, v)
            }
        }
    }

    Divider {
        width: parent.width
    }

    AudioDevices {
        width: parent.width
    }

    AudioDevices {
        width: parent.width
        inputs: true
    }
}
