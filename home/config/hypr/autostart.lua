local hl = hl or error("no hl")

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("xdg-terminal-exec sh -c 'fastfetch ; exec $SHELL'")
end)
