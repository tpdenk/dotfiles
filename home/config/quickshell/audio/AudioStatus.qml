pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import qs

// State of the machine's audio: the PipeWire default sink and source, their
// volume and mute, and the devices the panel can switch between.
Singleton {
    id: root

    // whether the details panel is open
    readonly property bool expanded: Panels.open === "audio"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // streams are applications playing through a device, not a device of
    // their own: per-application volumes are out of scope
    readonly property var sinks: devicesOf(true)
    readonly property var sources: devicesOf(false)

    // default first, then by name: any ordering that follows volume or node
    // id would reshuffle the list under the pointer while the panel is open
    function devicesOf(wantSink: bool): var {
        const preferred = wantSink ? root.sink : root.source;
        return (Pipewire.nodes?.values ?? []).filter(n => n.audio && n.isSink === wantSink && !n.isStream).sort((a, b) => {
            if ((a === preferred) !== (b === preferred))
                return a === preferred ? -1 : 1;
            return label(a).localeCompare(label(b));
        });
    }

    // PipeWire's own names are cryptic; the description is what pavucontrol
    // and wpctl show
    function label(node: var): string {
        return node ? node.description || node.nickname || node.name || "" : "";
    }

    // no sink means nothing is audible, which reads as muted
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property real inputVolume: source?.audio?.volume ?? 0
    readonly property bool inputMuted: source?.audio?.muted ?? true

    function setVolume(node: var, v: real): void {
        if (!node?.audio)
            return;
        node.audio.volume = Math.max(0, Math.min(1, v));
    }

    function setMuted(node: var, m: bool): void {
        if (!node?.audio)
            return;
        node.audio.muted = m;
    }

    // one detent of the volume keys, and one press of a keyboard's volume
    // rocker
    readonly property real volumeStep: 0.05

    // turning it up while muted means "make it audible", so stepping up
    // unmutes; stepping down leaves mute alone, as silence is what was asked
    // for either way
    function stepVolume(node: var, delta: real): void {
        if (!node?.audio)
            return;
        setVolume(node, node.audio.volume + delta);
        if (delta > 0)
            setMuted(node, false);
    }

    function toggleMuted(node: var): void {
        if (!node?.audio)
            return;
        setMuted(node, !node.audio.muted);
    }

    // the preferred* properties are the writable ones; default* only report
    // what PipeWire settled on
    function makeDefault(node: var): void {
        if (!node)
            return;
        if (node.isSink)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    // crossed out when silent, then a bare speaker, one wave, two waves. MDI's
    // `volume-low` draws no waves at all, so it is kept for the last few
    // percent before silence: anything actually audible shows a wave.
    readonly property string icon: String.fromCodePoint(muted || volume <= 0 ? 0xf0581 : volume <= 0.05 ? 0xf057f : volume < 0.5 ? 0xf0580 : 0xf057e)

    // the bar pill's text; muted still shows the level it would return to
    readonly property string volumeLabel: `${Math.round(volume * 100)}%`

    // pipewire only streams a node's volume/mute while something binds it
    PwObjectTracker {
        objects: root.sinks.concat(root.sources)
    }
}
