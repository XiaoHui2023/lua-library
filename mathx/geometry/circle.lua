---@class lib.mathx.geometry
local geometry = require "mathx.geometry.base"

---@param position lib.point
---@param radius number
---@return lib.mathx.geometry.circle
function geometry.circle(position, radius)
    ---@class lib.mathx.geometry.circle
    local o = {}

    ---@type lib.mathx.geometry.point
    o.position = geometry.point(position)

    ---@type number
    o.radius = math.abs(radius)

    ---@param point lib.point
    ---@return boolean
    function o.contains(point)
        return geometry.distance(o.position, point) <= o.radius
    end

    ---@param other lib.mathx.geometry.circle
    ---@return boolean
    function o.intersects(other)
        return geometry.distance(o.position, other.position) <= o.radius + other.radius
    end

    ---@return lib.mathx.geometry.rectangle
    function o.bounds()
        return geometry.rectangle(o.position, o.radius * 2, o.radius * 2)
    end

    ---@param position lib.point
    ---@param radius number
    ---@return boolean
    function o.intersects_circle(position, radius)
        return geometry.circles_intersect(o.position, o.radius, position, radius)
    end

    return o
end

---@param position lib.point
---@param radius number
---@param point lib.point
---@return boolean
function geometry.circle_contains(position, radius, point)
    radius = math.abs(radius)
    return geometry.distance_squared(position, point) <= radius * radius
end

---@param first_position lib.point
---@param first_radius number
---@param second_position lib.point
---@param second_radius number
---@return boolean
function geometry.circles_intersect(first_position, first_radius, second_position, second_radius)
    local total_radius = math.abs(first_radius) + math.abs(second_radius)
    return geometry.distance_squared(first_position, second_position) <= total_radius * total_radius
end
