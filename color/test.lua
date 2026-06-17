local source = debug.getinfo(1, "S").source
local color_dir = source:sub(1, 1) == "@" and source:sub(2) or source
color_dir = color_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = color_dir:match("^(.*)[/\\][^/\\]+$") or color_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local color = require "color"

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_eq") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

local function assert_near(actual, expected, epsilon, message)
    if math.abs(actual - expected) > epsilon then
        error((message or "assert_near") .. ": got " .. tostring(actual) .. ", want ~" .. tostring(expected))
    end
end

assert(type(color.RED) == "table")
assert_eq(color.RED.red, 255)
assert_eq(color.RED.green, 3)
assert_eq(color.RED.blue, 3)
assert(color.is_color(color.RED), "predefined color should be recognized")
assert(not color.is_color({ red = 255, green = 0, blue = 0 }), "plain tables are not color objects")
assert_eq(tostring(color.RED), "#FF0303")

local ok = pcall(function()
    color.RED.red = 0
end)
assert(not ok, "predefined colors should be read-only")
assert_eq(color.RED.red, 255)

assert(#color.MAP > 0)
local map = color.get_map()
assert_eq(#map, #color.MAP)
map[1] = color.BLACK
assert_eq(color.get_map()[1], color.RED, "get_map should return a copy")

math.randomseed(1)
local picked = color.random()
local found = false
for _, co in ipairs(color.MAP) do
    if co == picked then
        found = true
        break
    end
end
assert(found, "random should pick from MAP")

local old_map = color.MAP
color.MAP = {}
picked = color.random()
assert(color.is_color(picked), "random should use the internal default map")
color.MAP = old_map

assert_eq(color.render(color.YELLOW, "hello"), "hello")

color.set_renderer(function(co, content)
    return string.format("[%d]", co.red) .. content
end)
assert_eq(color.render(color.RED, "x"), "[255]x")
assert_eq(color.render(nil, 12), "[255]12")
color.reset_renderer()
assert_eq(color.render(color.RED, "x"), "x")
ok = pcall(color.render, { red = 255, green = 0, blue = 0 }, "x")
assert(not ok, "render should reject non-color tables")

color.clear_patterns()
color.add_pattern("#%x%x%x%x%x%x")
color.add_pattern("#%x%x%x%x%x%x")
assert_eq(#color.PATTERNS, 1)
local cleaned, count = color.remove("#FF0000name#00FF00")
assert_eq(cleaned, "name")
assert_eq(count, 2)

local patterns = color.get_patterns()
patterns[1] = "changed"
assert_eq(color.PATTERNS[1], "#%x%x%x%x%x%x")

local d = color.distance(color.WHITE, color.BLACK)
assert_near(d, 764.8339663572415, 0.000001, "white to black distance")
ok = pcall(color.distance, color.WHITE, { red = 0, green = 0, blue = 0 })
assert(not ok, "distance should reject non-color tables")

assert_eq(color.hue(color.define(255, 0, 0)), 0, "red hue")
assert_eq(color.hue(color.define(255, 255, 0)), 42, "yellow hue")
assert_eq(color.hue(color.define(0, 255, 0)), 85, "green hue")
assert_eq(color.hue(color.define(0, 0, 255)), 170, "blue hue")
assert_eq(color.nearest(color.define(250, 5, 5)), color.RED, "nearest red")
assert_eq(color.nearest(color.define(1, 2, 250), { color.RED, color.BLUE }), color.BLUE, "nearest in custom map")

local from_hex = color.from_hex("#0A1B2C")
assert(color.is_color(from_hex), "from_hex should return a color")
assert_eq(from_hex.red, 10)
assert_eq(from_hex.green, 27)
assert_eq(from_hex.blue, 44)
assert_eq(color.to_hex(from_hex), "#0A1B2C")
assert_eq(color.to_hex(color.from_hex("ffffff")), "#FFFFFF")

ok = pcall(color.define, 256, 0, 0)
assert(not ok, "define should reject out-of-range values")

ok = pcall(color.from_hex, "#FFF")
assert(not ok, "from_hex should reject short hex")

ok = pcall(color.to_hex, { red = 255, green = 255, blue = 255 })
assert(not ok, "to_hex should reject non-color tables")

ok = pcall(color.nearest, color.RED, {})
assert(not ok, "nearest should reject empty maps")

ok = pcall(color.nearest, color.RED, { { red = 255, green = 0, blue = 0 } })
assert(not ok, "nearest should reject non-color map entries")

ok = pcall(color.add_pattern, nil)
assert(not ok, "add_pattern should reject non-string pattern")

ok = pcall(color.set_renderer, nil)
assert(not ok, "set_renderer should reject non-function renderer")

print("color test ok")
