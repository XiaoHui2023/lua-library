---@class lib.color
---@field red integer
---@field green integer
---@field blue integer

---@class lib.colorlib
---@field MAP lib.color[]
---@field PATTERNS string[]
---@field define fun(red: integer, green: integer, blue: integer): lib.color
---@field is_color fun(value: any): boolean
---@field from_hex fun(hex: string): lib.color
---@field to_hex fun(co: lib.color): string
---@field distance fun(a: lib.color, b: lib.color): number
---@field hue fun(co: lib.color): number
---@field nearest fun(co: lib.color, map?: lib.color[]): lib.color
---@field random fun(): lib.color
---@field get_map fun(): lib.color[]
---@field remove fun(text: string): string, integer
---@field add_pattern fun(pattern: string)
---@field clear_patterns fun()
---@field get_patterns fun(): string[]
---@field set_renderer fun(fn: fun(co: lib.color, content: string): string)
---@field reset_renderer fun()
---@field render fun(co: lib.color, content: string): string
---@field RED lib.color
---@field BLUE lib.color
---@field CYAN lib.color
---@field PURPLE lib.color
---@field YELLOW lib.color
---@field ORANGE lib.color
---@field GREEN lib.color
---@field PINK lib.color
---@field GRAY lib.color
---@field LIGHT_GRAY lib.color
---@field LIGHT_BLUE lib.color
---@field LIGHT_GREEN lib.color
---@field DARK_GREEN lib.color
---@field BROWN lib.color
---@field WHITE lib.color
---@field BLACK lib.color

---@type lib.colorlib
local g = {}

---@type lib.color[]
g.MAP = {}

---@type string[]
g.PATTERNS = {}

---@type lib.color[]
local default_map = {}

local default_renderer = function(_, content)
    return content
end

local renderer = default_renderer

local color_metatable

---@return lib.color
local function new_color()
    return setmetatable({}, color_metatable)
end

color_metatable = {
    ---@param co lib.color
    ---@param content string
    ---@return string
    __call = function(co, content)
        return g.render(co, content)
    end,
    __index = function(co, key)
        return color_metatable.values[co][key]
    end,
    __newindex = function()
        error("color is read-only", 2)
    end,
    __pairs = function(co)
        return next, color_metatable.values[co], nil
    end,
    __tostring = function(co)
        return g.to_hex(co)
    end,
    values = setmetatable({}, { __mode = "k" }),
}

---@param value any
---@param name string
local function assert_byte(value, name)
    assert(type(value) == "number", name .. " must be a number")
    assert(value % 1 == 0, name .. " must be an integer")
    assert(value >= 0 and value <= 255, name .. " must be between 0 and 255")
end

---@param co any
---@param name string
local function assert_color(co, name)
    assert(g.is_color(co), name .. " must be a color")
end

---@param value any
---@return boolean
g.is_color = function(value)
    return type(value) == "table" and color_metatable.values[value] ~= nil
end

---@param color_1 lib.color
---@param color_2 lib.color
---@return number
g.distance = function(color_1, color_2)
    assert_color(color_1, "color_1")
    assert_color(color_2, "color_2")

    local R1, G1, B1 = color_1.red, color_1.green, color_1.blue
    local R2, G2, B2 = color_2.red, color_2.green, color_2.blue
    local rmean = (R1 + R2) / 2
    local R = R1 - R2
    local G = G1 - G2
    local B = B1 - B2

    return math.sqrt((2 + rmean / 256) * (R ^ 2) + 4 * (G ^ 2) + (2 + (255 - rmean) / 256) * (B ^ 2))
end

---@param co lib.color
---@return number
g.hue = function(co)
    assert_color(co, "co")

    local red = co.red / 255
    local green = co.green / 255
    local blue = co.blue / 255
    local max = math.max(red, green, blue)
    local min = math.min(red, green, blue)
    local delta = max - min

    if delta == 0 then
        return 0
    end

    local h
    if max == red then
        h = ((green - blue) / delta) % 6
    elseif max == green then
        h = (blue - red) / delta + 2
    else
        h = (red - green) / delta + 4
    end

    return math.floor(h * 60 * 256 / 360)
end

---@param red integer
---@param green integer
---@param blue integer
---@return lib.color
g.define = function(red, green, blue)
    assert_byte(red, "red")
    assert_byte(green, "green")
    assert_byte(blue, "blue")

    local co = new_color()
    color_metatable.values[co] = {
        red = red,
        green = green,
        blue = blue,
    }
    return co
end

---@param hex string
---@return lib.color
g.from_hex = function(hex)
    assert(type(hex) == "string", "hex must be a string")

    local red, green, blue = hex:match("^#?(%x%x)(%x%x)(%x%x)$")
    assert(red and green and blue, "hex must be in #RRGGBB or RRGGBB format")

    return g.define(tonumber(red, 16), tonumber(green, 16), tonumber(blue, 16))
end

---@param co lib.color
---@return string
g.to_hex = function(co)
    assert_color(co, "co")
    return string.format("#%02X%02X%02X", co.red, co.green, co.blue)
end

g.RED = g.define(255, 3, 3)
g.BLUE = g.define(0, 126, 255)
g.CYAN = g.define(28, 230, 185)
g.PURPLE = g.define(84, 0, 129)
g.YELLOW = g.define(255, 252, 1)
g.ORANGE = g.define(254, 138, 14)
g.GREEN = g.define(32, 192, 0)
g.PINK = g.define(229, 91, 176)
g.GRAY = g.define(149, 150, 151)
g.LIGHT_GRAY = g.define(200, 200, 200)
g.LIGHT_BLUE = g.define(126, 191, 241)
g.LIGHT_GREEN = g.define(102, 255, 153)
g.DARK_GREEN = g.define(16, 98, 70)
g.BROWN = g.define(78, 42, 4)
g.WHITE = g.define(255, 255, 255)
g.BLACK = g.define(0, 0, 0)

for _, co in ipairs({
    g.RED,
    g.BLUE,
    g.CYAN,
    g.PURPLE,
    g.YELLOW,
    g.ORANGE,
    g.GREEN,
    g.PINK,
    g.GRAY,
    g.LIGHT_GRAY,
    g.LIGHT_BLUE,
    g.LIGHT_GREEN,
    g.DARK_GREEN,
    g.BROWN,
    g.WHITE,
    g.BLACK,
}) do
    table.insert(g.MAP, co)
    table.insert(default_map, co)
end

---@return lib.color[]
g.get_map = function()
    local colors = {}
    for i, co in ipairs(default_map) do
        colors[i] = co
    end
    return colors
end

---@return lib.color
g.random = function()
    return default_map[math.random(1, #default_map)]
end

---@param co lib.color
---@param map? lib.color[]
---@return lib.color
g.nearest = function(co, map)
    assert_color(co, "co")
    map = map or default_map
    assert(type(map) == "table", "map must be a table")
    assert(#map > 0, "map must not be empty")

    local best = map[1]
    assert_color(best, "map[1]")
    local best_distance = g.distance(co, best)

    for i = 2, #map do
        local candidate = map[i]
        assert_color(candidate, "map[" .. i .. "]")
        local candidate_distance = g.distance(co, candidate)
        if candidate_distance < best_distance then
            best = candidate
            best_distance = candidate_distance
        end
    end

    return best
end

---@param s string
---@return string
---@return integer
g.remove = function(s)
    s = tostring(s or "")
    local total = 0
    for _, pattern in ipairs(g.PATTERNS) do
        local count
        s, count = string.gsub(s, pattern, "")
        total = total + count
    end
    return s, total
end

---@param pattern string
g.add_pattern = function(pattern)
    assert(type(pattern) == "string", "pattern must be a string")
    for _, existing in ipairs(g.PATTERNS) do
        if existing == pattern then
            return
        end
    end
    table.insert(g.PATTERNS, pattern)
end

g.clear_patterns = function()
    for i = #g.PATTERNS, 1, -1 do
        g.PATTERNS[i] = nil
    end
end

---@return string[]
g.get_patterns = function()
    local patterns = {}
    for i, pattern in ipairs(g.PATTERNS) do
        patterns[i] = pattern
    end
    return patterns
end

---@param fn fun(co: lib.color, content: string): string
g.set_renderer = function(fn)
    assert(type(fn) == "function", "renderer must be a function")
    renderer = fn
end

g.reset_renderer = function()
    renderer = default_renderer
end

---@param co lib.color
---@param content string
---@return string
g.render = function(co, content)
    co = co or g.WHITE
    assert_color(co, "co")
    content = tostring(content or "")
    return renderer(co, content)
end

return g
