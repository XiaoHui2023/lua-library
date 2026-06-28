---@class lib.module
---@field system lib.module.system.registry
---@field composition lib.module.composition.registry
---@field addon lib.module.addon.registry
---@field base lib.module.base
local M = {}

local module_path = ... or "module"

M.system = require(module_path .. ".system")
M.composition = require(module_path .. ".composition")
M.addon = require(module_path .. ".addon")
M.base = require(module_path .. ".base")

return M
