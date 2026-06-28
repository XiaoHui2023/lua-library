local create_machine = require "lib.state_machine.machine"
local create_state = require "lib.state_machine.state"

---@param value any
---@return boolean
local function is_state(value)
    return type(value) == "table" and value.type == "state_machine.state"
end

---@param source table
---@return table
local function shallow_copy(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

---@class lib.state_machine.builder.options
---@field registry? lib.state_machine.registry
---@field resolve_factory? fun(key:string, options:table, builder:lib.state_machine.builder):fun(options:table):lib.state_machine.state
---@field machine? lib.state_machine.machine
---@field name? string
---@field group_name? string

---@class lib.state_machine.builder
local Builder = {}
Builder.__index = Builder

---@param args? lib.state_machine.builder.options
---@return lib.state_machine.builder
local function create_builder(args)
    args = args or {}
    return setmetatable({
        registry = args.registry,
        resolve_factory = args.resolve_factory,
        machine = args.machine,
        name = args.name or "state_tree",
        group_name = args.group_name or "state_group",
    }, Builder)
end

---@param key string
---@param options table
---@return fun(options:table):lib.state_machine.state
function Builder:resolve(key, options)
    if self.resolve_factory ~= nil then
        local generator = self.resolve_factory(key, options, self)
        if generator ~= nil then
            return generator
        end
    end
    if self.registry ~= nil then
        return self.registry:get(key)
    end
    error("state template not found: " .. tostring(key), 2)
end

---@param options? table|lib.state_machine.state
---@return table
local function normalize_build_options(options)
    if is_state(options) then
        return { parent = options }
    end
    return options or {}
end

---@param self lib.state_machine.builder
---@param tree_level table
---@param level_parent lib.state_machine.state
local function build_level(self, tree_level, level_parent)
    for _, item in ipairs(tree_level) do
        if type(item) == "table" and #item > 0 then
            local child = create_state({
                name = item.name or self.group_name,
                machine = level_parent.machine,
                on_entry = function(state)
                    state:start_children()
                end,
            })
            level_parent:add_child(child)
            build_level(self, item, child)
        else
            local options = item and shallow_copy(item) or {}
            local key = options.key
            options.machine = level_parent.machine

            local state
            if key ~= nil then
                state = self:resolve(key, options)(options)
                if state.machine ~= level_parent.machine then
                    error("state template must create state in the current machine", 2)
                end
            else
                state = create_state(options)
            end
            level_parent:add_child(state)
        end
    end
end

---@param tree table
---@param options? table|lib.state_machine.state
---@return lib.state_machine.state
function Builder:build_tree(tree, options)
    assert(type(tree) == "table", "state tree must be table")
    options = normalize_build_options(options)

    local parent = options.parent
    if parent == nil then
        parent = create_state({
            name = options.name or self.name,
            machine = options.machine or self.machine or create_machine({
                name = options.machine_name or options.name or self.name,
                owner = options.owner,
            }),
            on_entry = function(state)
                state:start_children()
            end,
        })
    end

    build_level(self, tree, parent)
    return parent
end

return create_builder
