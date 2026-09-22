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

hl.layer_rule({
    name = "share-outline",
    match = { namespace = "^share-outline$" },

    no_anim = true,
})
