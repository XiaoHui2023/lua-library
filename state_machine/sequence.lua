local create_machine = require "lib.state_machine.machine"
local create_state = require "lib.state_machine.state"

---@param value any
---@return boolean
local function is_state(value)
    return type(value) == "table" and value.type == "state_machine.state"
end

---@param name string
---@param steps (lib.state_machine.state|lib.state_machine.state.options)[]
---@param args? lib.state_machine.machine.options
---@return lib.state_machine.state first
---@return lib.state_machine.state last
return function(name, steps, args)
    assert(type(steps) == "table" and #steps > 0, "steps must be non-empty array")
    args = args or {}
    local machine = args.machine or create_machine({
        name = args.name or name,
        owner = args.owner,
    })

    local first = nil
    local previous = nil
    for index, step in ipairs(steps) do
        local state = step
        if not is_state(step) then
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
