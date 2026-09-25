local hl = hl or error("no hl")
local theme = require("theme")

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 2,

        border_size = theme.int("border_size"),

        col = {
            active_border = { colors = { theme.get("accent"), theme.get("accent_secondary") }, angle = 45 },
            inactive_border = theme.rgba("muted", "55"),
        },

        resize_on_border = true,
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = theme.int("window_rounding"),
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,

        dim_inactive = true,
        dim_strength = 0.1,

        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = theme.rgba("background", "cc"),
        },

        glow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = { colors = { theme.rgba("accent", "88"), theme.rgba("accent_secondary", "88") }, angle = 45 },
            -- glow marks the focused window only
            color_inactive = theme.rgba("background", "00"),
        },

        blur = {
            enabled = true,
            size = 3,
            passes = 2,
            noise = 0.0117,
            contrast = 0.9,
            brightness = 1.0,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        use_active_for_splits = true,
        force_split = 2, -- right bottom
    },
})
