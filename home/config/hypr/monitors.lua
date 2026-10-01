local hl = hl or error("no hl")

hl.monitor({
    output = "Virtual-1",
    mode = "2880x1800@120",
    position = "0x0",
    scale = "1.8",
})

-- machine-specific monitors, created by bootstrap.sh if missing
local configHome = os.getenv("XDG_CONFIG_HOME")
if not configHome or configHome == "" then
    configHome = os.getenv("HOME") .. "/.config"
end
local localMonitors = configHome .. "/hypr-local/monitors.lua"
local f = io.open(localMonitors, "r")
if f then
    f:close()
    -- require (not dofile) so hyprland's autoreload watches the file
    require(localMonitors)
end
