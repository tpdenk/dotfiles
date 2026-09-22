import qs
import qs.widgets

// The audio details card: title, output and input controls, device pickers.
PanelCard {
    title: "Audio"

    AudioControls {
        width: parent.width
        node: AudioStatus.sink
        placeholder: "No output"
    }

    Divider {
        width: parent.width
    }

    AudioControls {
        width: parent.width
        node: AudioStatus.source
        placeholder: "No input"
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
