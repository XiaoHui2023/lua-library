---@class lib.mathx.geometry
local geometry = require "mathx.geometry.base"

---@param position lib.point
---@param width number
---@param height number
---@return lib.mathx.geometry.rectangle
function geometry.rectangle(position, width, height)
    ---@class lib.mathx.geometry.rectangle
    local o = {}

    ---@type lib.mathx.geometry.point
    o.position = geometry.point(position)

    ---@type number
    o.width = math.abs(width)

    ---@type number
    o.height = math.abs(height)

    ---@return number
    function o.left()
        return o.position.x - o.width / 2
    end

    ---@return number
    function o.right()
        return o.position.x + o.width / 2
    end

    ---@return number
    function o.top()
        return o.position.y - o.height / 2
    end

    ---@return number
    function o.bottom()
        return o.position.y + o.height / 2
    end

    ---@return lib.mathx.geometry.point
    function o.top_left()
        return geometry.point({x = o.left(), y = o.top()})
    end

    ---@return lib.mathx.geometry.point
    function o.top_right()
        return geometry.point({x = o.right(), y = o.top()})
    end

    ---@return lib.mathx.geometry.point
    function o.bottom_left()
        return geometry.point({x = o.left(), y = o.bottom()})
    end

    ---@return lib.mathx.geometry.point
    function o.bottom_right()
        return geometry.point({x = o.right(), y = o.bottom()})
    end

    ---@param point lib.point
    ---@return boolean
    function o.contains(point)
        local x = geometry.get_x(point)
        local y = geometry.get_y(point)
        return x >= o.left()
            and x <= o.right()
            and y >= o.top()
            and y <= o.bottom()
    end

    ---@param other lib.mathx.geometry.rectangle
    ---@return boolean
    function o.intersects(other)
        return o.left() <= other.right()
            and o.right() >= other.left()
            and o.top() <= other.bottom()
            and o.bottom() >= other.top()
    end

    return o
end
