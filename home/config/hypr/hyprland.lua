require("monitors")
require("input")
require("bindings")
require("autostart")
require("lookandfeel")
require("animations")

local hl = hl or error("no hl")

local suppressMaximizeRule = hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },

    no_focus = true,
})

hl.window_rule({
    name = "float-file-chooser",
    match = { class = "^filechooser$" },

    float = true,
    size = { 1536, 1008 },
})

hl.window_rule({
    name = "float-notes",
    match = { class = "^org\\.quickshell$", title = "^Notes$" },

    float = true,
    center = true,
})

-- view: Brave names an --app window after its URL, and a file:// URL has no
-- host, which gives the "__"
hl.window_rule({
    name = "float-view",
    match = { class = "^brave-__.+$" },

    float = true,
    center = true,
    size = "monitor_w*0.6 monitor_h*0.8",
})

hl.layer_rule({
    name = "share-outline",
    match = { namespace = "^share-outline$" },

    no_anim = true,
})

-- slurp: a screenshot is taken as it closes and must not find it fading out
hl.layer_rule({
    name = "share-picker",
    match = { namespace = "^selection$" },

    no_anim = true,
})
