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

    ---@return lib.mathx.geometry.rectangle
    function o.bounds()
        local min_x
        local max_x
        local min_y
        local max_y
        for _, point in ipairs(o.points) do
            local x = geometry.get_x(point)
            local y = geometry.get_y(point)
            min_x = min_x == nil and x or math.min(min_x, x)
            max_x = max_x == nil and x or math.max(max_x, x)
            min_y = min_y == nil and y or math.min(min_y, y)
            max_y = max_y == nil and y or math.max(max_y, y)
        end
        min_x = min_x or 0
        max_x = max_x or 0
        min_y = min_y or 0
        max_y = max_y or 0
        return geometry.rectangle({
            x = (min_x + max_x) / 2,
            y = (min_y + max_y) / 2,
        }, max_x - min_x, max_y - min_y)
    end

    ---@param point lib.point
    ---@return boolean
    function o.contains(point)
        local x = geometry.get_x(point)
        local y = geometry.get_y(point)
        local inside = false
        local count = #o.points
        if count < 3 then
            return false
        end
        local previous = o.points[count]
        for _, current in ipairs(o.points) do
            local xi = geometry.get_x(current)
            local yi = geometry.get_y(current)
            local xj = geometry.get_x(previous)
            local yj = geometry.get_y(previous)
            if ((yi > y) ~= (yj > y)) and (x <= (xj - xi) * (y - yi) / (yj - yi) + xi) then
                inside = not inside
            end
            previous = current
        end
        return inside
    end

    ---@param position lib.point
    ---@param radius number
    ---@return boolean
    function o.intersects_circle(position, radius)
        if o.contains(position) then
            return true
        end
        radius = math.abs(radius)
        local count = #o.points
        if count == 0 then
            return false
        end
        local previous = o.points[count]
        local px = geometry.get_x(position)
        local py = geometry.get_y(position)
        for _, current in ipairs(o.points) do
            local ax = geometry.get_x(previous)
            local ay = geometry.get_y(previous)
            local bx = geometry.get_x(current)
            local by = geometry.get_y(current)
            local dx = bx - ax
            local dy = by - ay
            local length_squared = dx * dx + dy * dy
            local t = 0
            if length_squared > 0 then
                t = ((px - ax) * dx + (py - ay) * dy) / length_squared
                t = math.max(0, math.min(1, t))
            end
            local nearest = {
                x = ax + dx * t,
                y = ay + dy * t,
            }
            if geometry.distance_squared(nearest, position) <= radius * radius then
                return true
            end
            previous = current
        end
        return false
    end

    return o
end
