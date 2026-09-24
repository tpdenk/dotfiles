import Quickshell
import Quickshell.Io
import qs.widgets

// Audio details, shown under the bar's AudioIndicator, and the media keys.
Scope {
    Dropdown {
        name: "audio"
        card: AudioPanel {}
    }

    VolumeOsd {}

    // the media keys act on the default output, the same device the bar
    // indicator and the panel's first slider show
    IpcHandler {
        target: "audio"

        function volumeUp(): void {
            AudioStatus.stepVolume(AudioStatus.sink, AudioStatus.volumeStep);
        }
        function volumeDown(): void {
            AudioStatus.stepVolume(AudioStatus.sink, -AudioStatus.volumeStep);
        }
        function toggleMute(): void {
            AudioStatus.toggleMuted(AudioStatus.sink);
        }
    }
}
