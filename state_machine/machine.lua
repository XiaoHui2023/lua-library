---@class lib.state_machine.machine.options
---@field name? string 字段说明
---@field owner? any 字段说明

---@class lib.state_machine.machine
---@field type string 类型标记
---@field name string 状态机名称
---@field owner any 归属对象
---@field states lib.state_machine.state[] 根状态列表
local Machine = {}
Machine.__index = Machine

---@param args? lib.state_machine.machine.options 参数说明
---@return lib.state_machine.machine
local function create_machine(args)
    args = args or {}
    local machine = {
        type = "state_machine.machine",
        name = args.name or "state_machine",
        owner = args.owner,
        states = {},
        _destroyed = false,
    }
    return setmetatable(machine, Machine)
end

---@param state lib.state_machine.state
function Machine:add_state(state)
    if self._destroyed then
        error("cannot add state to destroyed machine: " .. tostring(self.name), 2)
    end
    for _, item in ipairs(self.states) do
        if item == state then
            return
        end
    end
    self.states[#self.states + 1] = state
end

---@param state lib.state_machine.state
function Machine:remove_state(state)
    for index, item in ipairs(self.states) do
        if item == state then
            table.remove(self.states, index)
            return
        end
    end
end

---@param event_name string
---@param ... any
function Machine:emit(event_name, ...)
    local states = {}
    for index, state in ipairs(self.states) do
        states[index] = state
    end
    for _, state in ipairs(states) do
        if not state:is_destroyed() then
            state:emit(event_name, ...)
        end
    end
end

---@param dt number
---@param context? any 参数说明
function Machine:update(dt, context)
    local states = {}
    for index, state in ipairs(self.states) do
        states[index] = state
    end
    for _, state in ipairs(states) do
        if not state:is_destroyed() then
            state:update(dt, context)
        end
    end
end

---@param reason? string 参数说明
function Machine:destroy(reason)
    if self._destroyed then
        return
    end
    self._destroyed = true

    local states = {}
    for index, state in ipairs(self.states) do
        states[index] = state
    end
    for _, state in ipairs(states) do
        state:destroy(reason or "machine_destroy")
    end
    self.states = {}
end

---@return boolean
function Machine:is_destroyed()
    return self._destroyed
end

return create_machine
