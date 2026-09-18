local hl = hl or error("no hl")

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 2,

        border_size = 2,

        col = {
            -- the original blue gradient, static: no `borderangle` animates it
            active_border = { colors = { "rgba(7aa2f7ff)", "rgba(bb9af7ff)" }, angle = 45 },
            inactive_border = "rgba(414868aa)",
        },

        resize_on_border = true,
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = 2,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 0.9,

        -- drives `fadeDim` on focus change
        dim_inactive = true,
        dim_strength = 0.25,

        -- drives `fadeShadow`
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = "rgba(1a1b26cc)",
        },

        -- drives `fadeGlow`; same blue -> purple as the border, just translucent
        glow = {
            enabled = true,
            range = 12,
            render_power = 3,
            color = { colors = { "rgba(7aa2f766)", "rgba(bb9af766)" }, angle = 45 },
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
    },
})
