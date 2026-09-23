pragma Singleton
import Quickshell

// Copies text to the wayland clipboard, announced with the same replacing
// toast SUPER+C raises (hypr/bindings.lua).
Singleton {
    readonly property string icon: String.fromCodePoint(0xf018f) // content copy

    function copy(text: string): void {
        if (text === "")
            return;
        // the toast only once wl-copy has taken the selection
        Quickshell.execDetached(["sh", "-c", 'wl-copy -- "$1" && exec notify-send -a clipboard -e -t 1500 -h string:x-canonical-private-synchronous:clipboard "Copied to clipboard"', "clipboard", text]);
    }
}
