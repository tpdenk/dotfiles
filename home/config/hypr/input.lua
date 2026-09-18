hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "dvorak",
        kb_options = "compose:caps,altwin:swap_alt_win",

        repeat_rate = 40,
        repeat_delay = 300,

        numlock_by_default = true,
        follow_mouse = 1,

        accel_profile = "flat",

        touchpad = {
            natural_scroll = true,
            clickfinger_behavior = true,
            scroll_factor = 0.2,
            disable_while_typing = true,
            drag_3fg = 1,
        }
    }
})
