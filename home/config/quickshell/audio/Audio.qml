import Quickshell
import Quickshell.Io
import QtQuick
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
            chime.restart();
        }
        function volumeDown(): void {
            AudioStatus.stepVolume(AudioStatus.sink, -AudioStatus.volumeStep);
            chime.restart();
        }
        function toggleMute(): void {
            AudioStatus.toggleMuted(AudioStatus.sink);
        }
    }

    // longer than hyprland's 300ms repeat_delay, so a held key chimes once,
    // at the level it ends on; played into the sink itself, the chime is
    // only as loud as what that output now plays at
    Timer {
        id: chime
        interval: 350
        onTriggered: {
            if (AudioStatus.sink)
                Quickshell.execDetached(["pw-play", "--target", AudioStatus.sink.name, "/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"]);
        }
    }
}
