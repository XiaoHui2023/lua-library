local source = debug.getinfo(1, "S").source
local mathx_dir = source:sub(1, 1) == "@" and source:sub(2) or source
mathx_dir = mathx_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = mathx_dir:match("^(.*)[/\\][^/\\]+$") or mathx_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local mathx = require "mathx"

local function assert_near(actual, expected, epsilon, message)
    if math.abs(actual - expected) > epsilon then
        error((message or "assert_near") .. ": got " .. tostring(actual) .. ", want ~" .. tostring(expected))
    end
end

mathx.use_lua_backend()
assert_near(mathx.sin(90), 1, 0.000001, "lua backend sin uses degrees")
assert_near(mathx.cos(180), -1, 0.000001, "lua backend cos uses degrees")
assert_near(mathx.asin(1), 90, 0.000001, "lua backend asin returns degrees")
assert_near(mathx.atan(1, 0), 90, 0.000001, "lua backend atan returns degrees")
assert_near(mathx.sin_radian(math.pi / 2), 1, 0.000001, "raw radian sin is available")
assert_near(mathx.raw.sin(mathx.raw.pi / 2), 1, 0.000001, "raw sin keeps Lua radians")

local value = mathx.random_real(5, 3)
assert(value >= 3 and value <= 5, "random_real should swap reversed range")
local angle = mathx.random_angle(90)
assert(angle >= -180 and angle <= 90, "random_angle should use the default minimum when max is omitted")

assert(mathx.round(1.4) == 1, "round should round down below half")
assert(mathx.round(1.5) == 2, "round should round half up")
assert(mathx.round(-1.5) == -2, "round should round negative half away from zero")
assert(mathx.r2i(1.9) == 1, "r2i should floor")
assert(mathx.int(-1.9) == -1, "int should truncate toward zero")

assert(mathx.angle_rule(540) == 180, "angle_rule should keep positive 180")
assert(mathx.angle_rule(-540) == -180, "angle_rule should keep negative 180")
assert(mathx.angle_abs(170, -170) == 20, "angle_abs should use shortest wrapped difference")

mathx.set_backend({
    random_float = function(min, max)
        return min + max
    end,
    random_int = function(min, max)
        return min * 10 + max
    end,
    sin = function(angle)
        return angle + 1
    end,
    asin = function(value)
        return value + 2
    end,
    cos = function(angle)
        return angle + 3
    end,
    atan = function(y, x)
        return y + x + 4
    end,
})

assert(mathx.random_real(2, 4) == 6, "custom backend random_float should be used")
assert(mathx.random_int(2, 4) == 24, "custom backend random_int should be used")
assert(mathx.sin(10) == 11, "custom backend sin should be used")
assert(mathx.asin(10) == 12, "custom backend asin should be used")
assert(mathx.cos(10) == 13, "custom backend cos should be used")
assert(mathx.atan(10, 20) == 34, "custom backend atan should be used")

mathx.set_backend({
    random_float = function(min, max)
        return min + max
    end,
    sin = function(angle)
        return math.sin(angle * math.pi / 180)
    end,
    asin = function(value)
        return math.asin(value) * 180 / math.pi
    end,
    cos = function(angle)
        return math.cos(angle * math.pi / 180)
    end,
    atan = function(y, x)
        return math.atan(y, x) * 180 / math.pi
    end,
})

assert_near(mathx.sin(90), 1, 0.000001, "backend recursion guard should expose raw sin")
assert_near(mathx.cos(180), -1, 0.000001, "backend recursion guard should expose raw cos")

mathx.set_backend({
    random_float = function(min, max)
        return mathx.random_real(min, max)
    end,
    random_int = function(min, max)
        return mathx.random_int(min, max)
    end,
    sin = function(angle)
        return math.sin(angle * math.pi / 180)
    end,
    asin = function(value)
        return math.asin(value) * 180 / math.pi
    end,
    cos = function(angle)
        return math.cos(angle * math.pi / 180)
    end,
    atan = function(y, x)
        return math.atan(y, x) * 180 / math.pi
    end,
})

local recursive_random = mathx.random_real(1, 2)
assert(recursive_random >= 1 and recursive_random <= 2, "recursive random_float should fall back to raw random")
local recursive_int = mathx.random_int(1, 2)
assert(recursive_int == 1 or recursive_int == 2, "recursive random_int should fall back to raw random")

local ok = pcall(mathx.set_backend, nil)
assert(not ok, "set_backend should reject non-table backend")

mathx.use_lua_backend()

local geometry = mathx.geometry
local p = geometry.point({x = 3, y = 4})
assert(geometry.distance_squared({x = 0, y = 0}, p) == 25, "distance_squared should work")
assert(geometry.distance({x = 0, y = 0}, p) == 5, "distance should work")
assert(p.move(1, 2).x == 4 and p.move(1, 2).y == 6, "point.move should return a moved copy")
assert(p.add({x = 2, y = 3}).x == 5 and p.add({x = 2, y = 3}).y == 7, "point.add should return a summed copy")
assert_near(geometry.point({x = 0, y = 0}).polar(10, 0).x, 10, 0.000001, "point.polar should use degrees")
assert(p.is_facing({x = 10, y = 4}, 0, 5), "point.is_facing should check angle range")

local rect = geometry.rectangle({x = 0, y = 0}, 10, 20)
assert(rect.contains({x = 5, y = 10}), "rectangle.contains should include borders")
assert(not rect.contains({x = 6, y = 0}), "rectangle.contains should reject outside points")
assert(rect.intersects(geometry.rectangle({x = 5, y = 0}, 10, 10)), "rectangle.intersects should detect overlap")
assert(geometry.rectangle({x = 0, y = 0}, -10, -20).contains({x = 5, y = 10}), "rectangle should normalize negative size")

local circle = geometry.circle({x = 0, y = 0}, 5)
assert(circle.contains({x = 3, y = 4}), "circle.contains should include borders")
assert(circle.intersects(geometry.circle({x = 8, y = 0}, 3)), "circle.intersects should detect touching circles")
assert(geometry.circle({x = 0, y = 0}, -5).contains({x = 3, y = 4}), "circle should normalize negative radius")
assert(geometry.circle_contains({x = 0, y = 0}, 5, {x = 3, y = 4}), "circle_contains should include borders")
assert(geometry.circles_intersect({x = 0, y = 0}, 5, {x = 8, y = 0}, 3), "circles_intersect should detect touching circles")

local grid = mathx.spatial_hash_grid.create({
    cell_size = 64,
    get_position = function(item)
        return item.position
    end,
    get_radius = function(item)
        return item.radius
    end,
})
local grid_a = { position = { x = 0, y = 0 }, radius = 10 }
local grid_b = { position = { x = 20, y = 0 }, radius = 10 }
local grid_c = { position = { x = 300, y = 0 }, radius = 10 }
grid.insert(grid_a)
grid.insert(grid_b)
grid.insert(grid_c)
local candidate_count = 0
grid.visit_circle_candidates({ x = 0, y = 0 }, 40, function()
    candidate_count = candidate_count + 1
end)
assert(candidate_count == 2, "spatial hash grid should visit nearby candidates")
grid_c.position = { x = 10, y = 0 }
grid.update(grid_c)
candidate_count = 0
grid.visit_circle_candidates({ x = 0, y = 0 }, 40, function()
    candidate_count = candidate_count + 1
end)
assert(candidate_count == 3, "spatial hash grid update should move candidates")

local convex = {
    {x = 0, y = 0},
    {x = 10, y = 0},
    {x = 10, y = 10},
    {x = 0, y = 10},
}
local concave = {
    {x = 0, y = 0},
    {x = 10, y = 0},
    {x = 5, y = 5},
    {x = 10, y = 10},
    {x = 0, y = 10},
}
assert(not mathx.is_concave_polygon(convex), "convex polygon should not be concave")
assert(mathx.is_concave_polygon(concave), "concave polygon should be concave")
assert(not mathx.is_concave_polygon({{x = 0, y = 0}, {x = 1, y = 1}, {x = 2, y = 0}}), "triangle cannot be concave")
assert(geometry.polygon(concave).is_concave(), "geometry.polygon should expose concavity")
assert(geometry.polygon(convex).contains({ x = 5, y = 5 }), "polygon contains should detect inside point")
assert(not geometry.polygon(convex).contains({ x = 15, y = 5 }), "polygon contains should reject outside point")
assert(geometry.polygon(convex).intersects_circle({ x = 11, y = 5 }, 2), "polygon should intersect touching circle")

local composite = geometry.composite_shape({
    shapes = {
        geometry.circle({ x = 0, y = 0 }, 10),
        geometry.rectangle({ x = 30, y = 0 }, 10, 10),
    },
})
assert(composite.contains({ x = 0, y = 0 }), "composite should contain point in first shape")
assert(composite.contains({ x = 30, y = 0 }), "composite should contain point in second shape")
assert(composite.intersects_circle({ x = 40, y = 0 }, 5), "composite should intersect circle near any shape")

print("mathx test ok")
