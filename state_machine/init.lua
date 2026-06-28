local create_machine = require "lib.state_machine.machine"
local create_state = require "lib.state_machine.state"
local create_registry = require "lib.state_machine.registry"
local create_builder = require "lib.state_machine.builder"
local sequence = require "lib.state_machine.sequence"

---@class lib.state_machine
local M = {}

M.machine = create_machine
M.state = create_state
M.create = create_state
M.registry = create_registry
M.builder = create_builder
M.sequence = sequence

local default_registry = create_registry({ name = "state_machine_default_registry" })

---@param key string
---@param generator fun(options:lib.state_machine.state.options):lib.state_machine.state
function M.register_template(key, generator)
    default_registry:register(key, generator)
end

---@param key string
---@return fun(options:lib.state_machine.state.options):lib.state_machine.state
function M.get_generator_by_key(key)
    return default_registry:get(key)
end

---@return lib.state_machine.registry
function M.default_registry()
    return default_registry
end

---@class lib.state_machine.tree_options: lib.state_machine.state.options
---@field key? string
---@alias lib.state_machine.tree (lib.state_machine.tree_options[]|lib.state_machine.tree[])

---@param tree lib.state_machine.tree
---@param options? table|lib.state_machine.state
---@return lib.state_machine.state
function M.build_tree(tree, options)
    return create_builder({ registry = default_registry }):build_tree(tree, options)
end

return M
