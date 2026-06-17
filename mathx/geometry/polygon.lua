---@class lib.mathx.geometry
local geometry = require "mathx.geometry.base"

---@param points lib.point[]
---@return lib.mathx.geometry.polygon
function geometry.polygon(points)
    ---@class lib.mathx.geometry.polygon
    local o = {}

    ---@type lib.point[]
    o.points = points or {}

    ---@return boolean
    function o.is_concave()
        return math.is_concave_polygon(o.points)
    end

    return o
end
