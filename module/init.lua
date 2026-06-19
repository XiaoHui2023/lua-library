---@class lib.module
local M = {}

local module_path = ... or "module"

M.system = require(module_path .. ".system")
M.blueprint = require(module_path .. ".blueprint")
M.addon = require(module_path .. ".addon")

return M
