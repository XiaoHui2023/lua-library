---@class lib.mathx.geometry
local M = {}

---@param value lib.point
---@return number
function M.get_x(value)
    if value.x ~= nil then
        return value.x
    end
    error("point.x is required", 2)
end

---@param value lib.point
---@return number
function M.get_y(value)
    if value.y ~= nil then
        return value.y
    end
    error("point.y is required", 2)
end

return M
