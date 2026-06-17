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

    return o
end
