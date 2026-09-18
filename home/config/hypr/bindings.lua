local hl = hl or error("no hl")

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("alacritty"))
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + N", hl.dsp.focus({ workspace = "empty" }))
hl.bind("SUPER + CTRL + T", hl.dsp.exec_cmd("alacritty -e btop"))
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + RIGHT", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + UP", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + DOWN", hl.dsp.focus({ direction = "d" }))

for workspace = 1, 10 do
    local key = "code:" .. tostring(workspace + 9)
    hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(workspace) }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(workspace) }))
    hl.bind("SUPER + CTRL + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(workspace), follow = false }))
end

hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratchpad"))

hl.bind("SUPER + CTRL + SHIFT + LEFT", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind("SUPER + CTRL + SHIFT + RIGHT", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind("SUPER + CTRL + SHIFT + UP", hl.dsp.workspace.move({ monitor = "u" }))
hl.bind("SUPER + CTRL + SHIFT + DOWN", hl.dsp.workspace.move({ monitor = "d" }))

hl.bind("SUPER + SHIFT + LEFT", hl.dsp.window.swap({ direction = "l" }))
hl.bind("SUPER + SHIFT + RIGHT", hl.dsp.window.swap({ direction = "r" }))
hl.bind("SUPER + SHIFT + UP", hl.dsp.window.swap({ direction = "u" }))
hl.bind("SUPER + SHIFT + DOWN", hl.dsp.window.swap({ direction = "d" }))

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
