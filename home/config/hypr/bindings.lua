local hl = hl or error("no hl")

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("$HOME/.local/bin/term-here"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("brave"))

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind("SUPER + CTRL + W", hl.dsp.exec_cmd("qs ipc call network toggle"))
hl.bind("SUPER + CTRL + B", hl.dsp.exec_cmd("qs ipc call bluetooth toggle"))
hl.bind("SUPER + CTRL + A", hl.dsp.exec_cmd("qs ipc call audio toggle"))
hl.bind("SUPER + CTRL + T", hl.dsp.exec_cmd("alacritty -e btop"))
hl.bind("SUPER + CTRL + P", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind("SUPER + CTRL + L", hl.dsp.exec_cmd("loginctl lock-session"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call audio volumeUp"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call audio volumeDown"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("qs ipc call audio toggleMute"), { locked = true })

local screenshot = "hyprshot -z -o $HOME/Pictures/Screenshots"
hl.bind("PRINT", hl.dsp.exec_cmd(screenshot .. " -m region"))
hl.bind("SUPER + PRINT", hl.dsp.exec_cmd("qs ipc call screenrecord start"))

hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + N", hl.dsp.focus({ workspace = "empty" }))
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

local TERMINALS = { Alacritty = true, kitty = true }

local function clipboard(key, text)
    return function()
        local win = hl.get_active_window()
        local mods = (win and TERMINALS[win.class]) and "CTRL SHIFT" or "CTRL"
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
        hl.timer(function()
            hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
        end, { timeout = 50, type = "oneshot" })
        hl.exec_cmd("notify-send -a clipboard -e -t 1500 -h string:x-canonical-private-synchronous:clipboard '" .. text .. "'")
        return { ok = true }
    end
end

hl.bind("SUPER + C", clipboard("c", "Copied to clipboard"))
hl.bind("SUPER + V", clipboard("v", "Pasted from clipboard"))
