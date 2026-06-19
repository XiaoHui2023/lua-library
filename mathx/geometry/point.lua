---@class lib.mathx.geometry
local geometry = require "mathx.geometry.base"

---@param p1 lib.point
---@param p2 lib.point
---@return number
function geometry.distance(p1, p2)
    local x1 = geometry.get_x(p1)
    local y1 = geometry.get_y(p1)
    local x2 = geometry.get_x(p2)
    local y2 = geometry.get_y(p2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

---@param point? lib.point 初始坐标；省略时使用原点
---@return lib.mathx.geometry.point
function geometry.point(point)
    point = point or {}

    ---@class lib.mathx.geometry.point : lib.point
    local o = {
        x = point.x ~= nil and point.x or 0,
        y = point.y ~= nil and point.y or 0,
    }

    ---返回按 x 和 y 偏移后的新点。
    ---@param x? number 横向偏移；省略时为 0
    ---@param y? number 纵向偏移；省略时为 0
    ---@return lib.mathx.geometry.point
    function o.move(x, y)
        x = x or 0
        y = y or 0
        return geometry.point({x = o.x + x, y = o.y + y})
    end

    ---返回与另一个点相加后的新点。
    ---@param point lib.point
    ---@return lib.mathx.geometry.point
    function o.add(point)
        return geometry.point({x = o.x + geometry.get_x(point), y = o.y + geometry.get_y(point)})
    end

    ---返回按极坐标偏移后的新点。
    ---@param distance number
    ---@param angle? number 角度，单位为度；省略时随机
    ---@return lib.mathx.geometry.point
    function o.polar(distance, angle)
        angle = angle or math.random_angle()
        local x = o.x + distance * math.cos(angle)
        local y = o.y + distance * math.sin(angle)
        return geometry.point({x = x, y = y})
    end

    ---@param point lib.point
    ---@return number
    function o.distance(point)
        return geometry.distance(o, point)
    end

    ---@param point lib.point
    ---@return number angle 角度，单位为度
    function o.angle(point)
        return math.atan(geometry.get_y(point) - o.y, geometry.get_x(point) - o.x)
    end

    ---@param point lib.point
    ---@param angle number 朝向角度，单位为度
    ---@param range? number 判定角度范围，单位为度；省略时为 90
    ---@return boolean
    function o.is_facing(point, angle, range)
        range = range or 90
        return math.angle_abs(angle, o.angle(point)) <= range
    end

    ---@param point lib.point
    ---@param angle number 朝向角度，单位为度
    ---@param range? number 判定角度范围，单位为度；省略时为 90
    ---@return boolean
    function o.is_behind(point, angle, range)
        return o.is_facing(point, angle + 180, range)
    end

    return o
end
