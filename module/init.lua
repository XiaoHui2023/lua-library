---@class lib.module
---@field system lib.module.system.registry
---@field blueprint lib.module.blueprint.registry
---@field addon lib.module.addon.registry
---@field base lib.module.base
local M = {}

local module_path = ... or "module"

M.system = require(module_path .. ".system")
M.blueprint = require(module_path .. ".blueprint")
M.addon = require(module_path .. ".addon")
M.base = require(module_path .. ".base")

return M
