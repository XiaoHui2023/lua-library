local create_machine = require "lib.state_machine.machine"
local create_state = require "lib.state_machine.state"

---@class lib.state_machine
---@field machine fun(args?:lib.state_machine.machine.options):lib.state_machine.machine 字段说明
---@field state fun(args?:lib.state_machine.state.options):lib.state_machine.state 字段说明
local M = {}

M.machine = create_machine
M.state = create_state
M.create = create_state

---@type table<string, fun(options:lib.state_machine.state.options):lib.state_machine.state>
local templates = {}

---@param name string
---@param steps (lib.state_machine.state|lib.state_machine.state.options)[]
---@param args? lib.state_machine.machine.options 参数说明
---@return lib.state_machine.state first
---@return lib.state_machine.state last
function M.sequence(name, steps, args)
    assert(type(steps) == "table" and #steps > 0, "steps must be non-empty array")
    args = args or {}
    local machine = create_machine({
        name = args.name or name,
        owner = args.owner,
    })

    local first = nil
    local previous = nil
    for index, step in ipairs(steps) do
        local state = step
        if type(step) ~= "table" or step.type ~= "state_machine.state" then
            local state_args = step or {}
            state_args.machine = machine
            state_args.name = state_args.name or (name .. "_" .. tostring(index))
            state = create_state(state_args)
        end

        if first == nil then
            first = state
        end
        if previous ~= nil then
            previous:transition_to(state)
        end
        previous = state
    end

    return first, previous
end

---@param key string
---@param generator fun(options:lib.state_machine.state.options):lib.state_machine.state
function M.register_template(key, generator)
    assert(type(key) == "string" and key ~= "", "template key must be non-empty string")
    assert(type(generator) == "function", "template generator must be function")
    templates[key] = generator
    M[key] = generator
end

---@param key string
---@return fun(options:lib.state_machine.state.options):lib.state_machine.state
function M.get_generator_by_key(key)
    local generator = templates[key] or M[key]
    if generator == nil then
        error("state template not found: " .. tostring(key), 2)
    end
    return generator
end

---@class lib.state_machine.tree_options: lib.state_machine.state.options
---@field key? string 字段说明
---@alias lib.state_machine.tree (lib.state_machine.tree_options[]|lib.state_machine.tree[])

---@param tree lib.state_machine.tree
---@param parent? lib.state_machine.state 参数说明
---@return lib.state_machine.state
function M.build_tree(tree, parent)
    assert(type(tree) == "table", "tree must be table")

    local function build_level(tree_level, level_parent)
        if level_parent == nil then
            level_parent = create_state({
                name = "state_tree",
                on_entry = function(state)
                    state:start_children()
                end,
            })
        end

        for _, item in ipairs(tree_level) do
            if type(item) == "table" and #item > 0 then
                local child = create_state({
                    name = "state_group",
                    machine = level_parent.machine,
                    on_entry = function(state)
                        state:start_children()
                    end,
                })
                level_parent:add_child(child)
                build_level(item, child)
            else
                local options = item or {}
                local key = options.key
                local state
                if key ~= nil then
                    options.machine = level_parent.machine
                    state = M.get_generator_by_key(key)(options)
                    if state.machine ~= level_parent.machine then
                        error("state template must create state in the current machine", 2)
                    end
                else
                    options.machine = level_parent.machine
                    state = create_state(options)
                end
                level_parent:add_child(state)
            end
        end

        return level_parent
    end

    return build_level(tree, parent)
end

return M
