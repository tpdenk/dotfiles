pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The desktop theme, read from ~/.config/hypr/theme.conf (the `$name = value`
// file hyprtoolkit.conf and hyprlock.conf `source`). Re-parses on every edit.
Singleton {
    id: root

    // same lookup order as hyprlang's findConfig
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property var vars: parse(file.text())

    readonly property color background: color("background")
    readonly property color base: color("base")
    readonly property color text: color("text")
    readonly property color brightText: color("bright_text")
    readonly property color muted: color("muted")
    readonly property color accent: color("accent")
    readonly property color accentSecondary: color("accent_secondary")

    readonly property int roundingLarge: int("rounding_large")
    readonly property int roundingSmall: int("rounding_small")
    readonly property int borderSize: int("border_size")

    readonly property string fontFamily: vars.font_family ?? ""
    readonly property int fontSize: int("font_size")
    readonly property int smallSize: int("small_font_size")
    readonly property int h1Size: int("h1_size")
    readonly property int h2Size: int("h2_size")

    FileView {
        id: file
        path: root.configHome + "/hypr/theme.conf"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    // `$name = value` lines, `#` comments stripped, `$ref`s resolved
    function parse(text: string): var {
        const raw = {};
        for (const line of text.split("\n")) {
            const m = line.replace(/#.*/, "").match(/^\s*\$(\w+)\s*=\s*(.*?)\s*$/);
            if (m)
                raw[m[1]] = m[2];
        }
        const resolve = value => value.replace(/\$(\w+)/g, (_, name) => resolve(raw[name] ?? ""));
        const vars = {};
        for (const name in raw)
            vars[name] = resolve(raw[name]);
        return vars;
    }

    // rgb(RRGGBB) | rgba(RRGGBBAA) | 0xAARRGGBB; missing -> transparent
    function color(name: string): color {
        const value = vars[name] ?? "";
        let m;
        if ((m = value.match(/^rgba\(([0-9a-f]{6})([0-9a-f]{2})\)$/i)))
            return "#" + m[2] + m[1];
        if ((m = value.match(/^rgb\(([0-9a-f]{6})\)$/i)))
            return "#" + m[1];
        if ((m = value.match(/^0x([0-9a-f]{8})$/i)))
            return "#" + m[1];
        return "transparent";
    }

    function int(name: string): int {
        return parseInt(vars[name]) || 0;
    }
}
