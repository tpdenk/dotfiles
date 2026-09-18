local path = debug.getinfo(1, "S").source:match("^@(.*/)") .. "theme.conf"

local raw = {}
local f = assert(io.open(path, "r"), "theme.conf missing next to theme.lua")
for line in f:lines() do
    local key, value = line:gsub("#.*", ""):match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
    if key then
        raw[key] = value
    end
end
f:close()

local function resolve(value)
    return (value:gsub("%$([%w_]+)", function(name)
        return resolve(assert(raw[name], "theme.conf: undefined $" .. name))
    end))
end

local vars = {}
for key, value in pairs(raw) do
    vars[key] = resolve(value)
end

local M = { vars = vars }

function M.get(name)
    return (assert(vars[name], "theme.conf: missing $" .. name))
end

function M.int(name)
    return assert(tonumber(M.get(name)), "theme.conf: $" .. name .. " is not a number")
end

-- rgb(RRGGBB) | rgba(RRGGBBAA) | 0xAARRGGBB -> RRGGBB
local function rgb(value)
    return value:match("^rgba?%((%x%x%x%x%x%x)%x*%)$") or value:match("^0x%x%x(%x%x%x%x%x%x)$")
end

function M.rgba(name, alpha)
    local value = M.get(name)
    return "rgba(" .. assert(rgb(value), "theme.conf: $" .. name .. " is not a color: " .. value) .. alpha .. ")"
end

return M
