local hl = hl or error("no hl")

hl.on("hyprland.start", function()
    hl.exec_cmd("alacritty")
end)
