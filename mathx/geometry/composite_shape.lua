---@class lib.mathx.geometry
local geometry = require "mathx.geometry.base"

---@class lib.mathx.geometry.composite_shape.options
---@field shapes? table[]
---@field exclude? table[]

---@param args? lib.mathx.geometry.composite_shape.options
---@return lib.mathx.geometry.composite_shape
function geometry.composite_shape(args)
    args = args or {}

    ---@class lib.mathx.geometry.composite_shape
    local o = {}
    o.shapes = args.shapes or {}
    o.exclude = args.exclude or {}

    local function any_contains(shapes, point)
        for _, shape in ipairs(shapes) do
            if shape.contains ~= nil and shape.contains(point) then
                return true
            end
        end
        return false
    end

    local function any_intersects_circle(shapes, position, radius)
        for _, shape in ipairs(shapes) do
            if shape.intersects_circle ~= nil and shape.intersects_circle(position, radius) then
                return true
            end
        end
        return false
    end

    ---@param point lib.point
    ---@return boolean
    function o.contains(point)
        return any_contains(o.shapes, point) and not any_contains(o.exclude, point)
    end

    ---@param position lib.point
    ---@param radius number
    ---@return boolean
    function o.intersects_circle(position, radius)
        return any_intersects_circle(o.shapes, position, radius)
            and not any_intersects_circle(o.exclude, position, radius)
    end

    ---@return lib.mathx.geometry.rectangle
    function o.bounds()
        local min_x
        local max_x
        local min_y
        local max_y
        for _, shape in ipairs(o.shapes) do
            if shape.bounds ~= nil then
                local bounds = shape.bounds()
                min_x = min_x == nil and bounds.left() or math.min(min_x, bounds.left())
                max_x = max_x == nil and bounds.right() or math.max(max_x, bounds.right())
                min_y = min_y == nil and bounds.top() or math.min(min_y, bounds.top())
                max_y = max_y == nil and bounds.bottom() or math.max(max_y, bounds.bottom())
            end
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

    return o
end

