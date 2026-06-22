---@class lib.motion
local M = {}
package.loaded[...] = M

---@class lib.motion.data
---@field origin_pos lib.point
---@field origin_z number
---@field reset_z number
---@field delta_pos lib.point
---@field delta_z number
---@field facing number
---@field dt number

---@class lib.motion.result
---@field data lib.motion.data
---@field final_pos lib.point
---@field final_z number

---@param args? table 参数说明
---@return lib.motion.data
function M.data(args)
    args = args or {}
    local origin_pos = args.origin_pos or args.pos or { x = 0, y = 0 }
    local delta_pos = args.delta_pos or { x = 0, y = 0 }

    return {
        origin_pos = {
            x = origin_pos.x or 0,
            y = origin_pos.y or 0,
        },
        origin_z = args.origin_z or args.z or 0,
        reset_z = args.reset_z or 0,
        delta_pos = {
            x = delta_pos.x or 0,
            y = delta_pos.y or 0,
        },
        delta_z = args.delta_z or 0,
        facing = args.facing or 0,
        dt = args.dt or 0,
    }
end

---@param data lib.motion.data
---@return lib.motion.result
function M.reset(data)
    data.delta_z = data.reset_z - data.origin_z
    return M.resolve(data)
end

---@param data lib.motion.data
---@return lib.motion.result
function M.resolve(data)
    return {
        data = data,
        final_pos = {
            x = data.origin_pos.x + data.delta_pos.x,
            y = data.origin_pos.y + data.delta_pos.y,
        },
        final_z = data.origin_z + data.delta_z,
    }
end

---@class lib.motion
require "lib.motion.modifier"
require "lib.motion.renderer"

return M
