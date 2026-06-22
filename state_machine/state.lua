---@type lib.callback
local callback = require "lib.callback"
local create_machine = require "lib.state_machine.machine"

---@alias lib.state_machine.state_status
---| "idle"
---| "running"
---| "done"
---| "interrupted"
---| "destroyed"

---@class lib.state_machine.state.options
---@field name? string 字段说明
---@field machine? lib.state_machine.machine 字段说明
---@field parent? lib.state_machine.state 字段说明
---@field owner? any 字段说明
---@field data? table 字段说明
---@field auto_start? boolean 字段说明
---@field on_run? fun(context:lib.state_machine.context) 字段说明
---@field on_entry? fun(state:lib.state_machine.state, 字段说明
---@field on_update? fun(state:lib.state_machine.state, 字段说明
---@field on_event? fun(state:lib.state_machine.state, 字段说明
---@field on_exit? fun(state:lib.state_machine.state, 字段说明
---@field on_interrupt? fun(state:lib.state_machine.state, 字段说明
---@field on_destroy? fun(state:lib.state_machine.state, 字段说明

---@class lib.state_machine.transition
---@field target lib.state_machine.state
---@field event? string 字段说明
---@field guard? fun(state:lib.state_machine.state, 字段说明
---@field action? fun(state:lib.state_machine.state, 字段说明

---@class lib.state_machine.context
---@field machine lib.state_machine.machine 所属状态机
---@field domain lib.state_machine.machine 兼容旧 state.domain，等同于 machine
---@field state lib.state_machine.state 当前状态
---@field data table 当前状态业务数据
---@field once_done fun() 标记当前状态完成
---@field done fun(reason?:string) 字段说明

---@class lib.state_machine.timer
---@field remaining number
---@field action fun(state:lib.state_machine.state)
---@field repeat_interval? number 字段说明
---@field active boolean

---@class lib.state_machine.state
---@field type string 类型标记
---@field name string 状态名
---@field machine lib.state_machine.machine 所属状态机
---@field parent? lib.state_machine.state 字段说明
---@field previous? lib.state_machine.state 字段说明
---@field children lib.state_machine.state[] 子状态
---@field data table 业务数据
---@field on_started lib.callback.event 启动事件
---@field on_done lib.callback.event 完成事件
---@field on_interrupted lib.callback.event 打断事件
---@field on_destroyed lib.callback.event 字段说明
---@field on_child_added lib.callback.event 子状态加入事件
local State = {}
State.__index = State

local function noop()
end

---@param value any
---@return boolean
local function is_state(value)
    return type(value) == "table" and value.type == "state_machine.state"
end

---@param args? lib.state_machine.state.options 参数说明
---@return lib.state_machine.state
local function create_state(args)
    args = args or {}
    local machine = args.machine
    if machine == nil then
        machine = create_machine({
            name = args.name and (args.name .. "_machine") or nil,
            owner = args.owner,
        })
    end

    local state = {
        type = "state_machine.state",
        name = args.name or "state",
        machine = machine,
        parent = nil,
        previous = nil,
        children = {},
        data = args.data or {},
        on_started = callback.event({ name = "state_machine.state.on_started" }),
        on_done = callback.event({ name = "state_machine.state.on_done" }),
        on_interrupted = callback.event({ name = "state_machine.state.on_interrupted" }),
        on_destroyed = callback.event({ name = "state_machine.state.on_destroyed" }),
        on_child_added = callback.event({ name = "state_machine.state.on_child_added" }),
        _status = "idle",
        _destroyed = false,
        _timers = {},
        _event_handlers = {},
        _transitions = {},
        _children_sequence_ready = false,
        _hooks = {
            on_entry = args.on_entry or noop,
            on_update = args.on_update or noop,
            on_event = args.on_event or noop,
            on_exit = args.on_exit or noop,
            on_interrupt = args.on_interrupt or noop,
            on_destroy = args.on_destroy or noop,
        },
    }
    setmetatable(state, State)

    if args.on_entry == nil and type(args.on_run) == "function" then
        state._hooks.on_entry = function(current_state, context)
            local run_context = {
                machine = current_state.machine,
                domain = current_state.machine,
                state = current_state,
                data = current_state.data,
                parent = current_state.parent,
                source = context and context.source or nil,
                target_point = context and context.target_point or nil,
            }
            run_context.done = function(reason)
                current_state:done(reason or "done")
            end
            run_context.once_done = function()
                current_state:done("once_done")
            end
            args.on_run(run_context)
        end
    end

    if args.parent ~= nil then
        args.parent:add_child(state, { auto_start = args.auto_start })
    else
        machine:add_state(state)
        if args.auto_start then
            state:start()
        end
    end

    return state
end

---@return string
function State:get_status()
    return self._status
end

---@return boolean
function State:is_running()
    return self._status == "running"
end

---@return boolean
function State:is_done()
    return self._status == "done" or self._status == "interrupted" or self._status == "destroyed"
end

---@return boolean
function State:is_destroyed()
    return self._destroyed
end

---@return string
function State:get_path()
    if self.parent == nil then
        return self.machine.name .. "/" .. self.name
    end
    return self.parent:get_path() .. "/" .. self.name
end

---@param context? any 参数说明
---@return lib.state_machine.state
function State:start(context)
    if self._destroyed or self._status == "running" then
        return self
    end
    self._status = "running"
    self._hooks.on_entry(self, context)
    self.on_started.run(self, context)
    return self
end

---@param dt number
---@param context? any 参数说明
---@return lib.state_machine.state
function State:update(dt, context)
    assert(type(dt) == "number", "dt must be number")
    if self._status ~= "running" then
        return self
    end

    self:_update_timers(dt)
    if self._status ~= "running" then
        return self
    end

    self._hooks.on_update(self, dt, context)

    local children = {}
    for index, child in ipairs(self.children) do
        children[index] = child
    end
    for _, child in ipairs(children) do
        child:update(dt, context)
    end

    return self
end

---@param reason? string 参数说明
---@return lib.state_machine.state
function State:done(reason)
    if self._destroyed or self._status == "done" or self._status == "interrupted" then
        return self
    end

    self._status = "done"
    self._hooks.on_exit(self, reason)
    self.on_done.run(self, reason)
    self:_try_transition(nil, reason)

    return self
end

---@param reason? string 参数说明
---@param passive? boolean 参数说明
---@return lib.state_machine.state
function State:interrupt(reason, passive)
    if self._destroyed or self._status == "interrupted" or self._status == "done" then
        return self
    end

    self._status = "interrupted"
    self._hooks.on_interrupt(self, reason, passive and true or false)
    self.on_interrupted.run(self, reason, passive and true or false)

    local children = {}
    for index, child in ipairs(self.children) do
        children[index] = child
    end
    for _, child in ipairs(children) do
        child:interrupt(reason or "parent_interrupt", true)
    end

    return self
end

---@param reason? string 参数说明
---@return lib.state_machine.state
function State:destroy(reason)
    if self._destroyed then
        return self
    end

    if self._status == "running" or self._status == "idle" then
        self:interrupt(reason or "destroy", true)
    end

    self._destroyed = true
    self._status = "destroyed"

    local children = {}
    for index, child in ipairs(self.children) do
        children[index] = child
    end
    for _, child in ipairs(children) do
        child:destroy(reason or "parent_destroy")
    end
    self.children = {}
    self._timers = {}
    self._event_handlers = {}
    self._transitions = {}

    self._hooks.on_destroy(self, reason)
    self.on_destroyed.run(self, reason)
    self.on_started.clear()
    self.on_done.clear()
    self.on_interrupted.clear()
    self.on_destroyed.clear()
    self.on_child_added.clear()

    if self.parent ~= nil then
        self.parent:remove_child(self)
    else
        self.machine:remove_state(self)
    end

    return self
end

---@param child_or_args lib.state_machine.state|lib.state_machine.state.options
---@param options? { 参数说明
---@return lib.state_machine.state
function State:add_child(child_or_args, options)
    options = options or {}
    local child = child_or_args
    if not is_state(child_or_args) then
        local args = child_or_args or {}
        args.machine = self.machine
        child = create_state(args)
    elseif child.machine ~= self.machine then
        error("child state must use the same machine", 2)
    end

    if child.parent == self then
        return child
    end
    if child.parent ~= nil then
        child.parent:remove_child(child)
    else
        child.machine:remove_state(child)
    end

    child.parent = self
    self.children[#self.children + 1] = child
    self.on_child_added.run(self, child)

    if options.auto_start then
        child:start()
    end
    return child
end

---@param child lib.state_machine.state
function State:remove_child(child)
    for index, item in ipairs(self.children) do
        if item == child then
            table.remove(self.children, index)
            if child.parent == self then
                child.parent = nil
            end
            return
        end
    end
end

---@param child_or_args lib.state_machine.state|lib.state_machine.state.options
---@return lib.state_machine.state
function State:spawn_child(child_or_args)
    return self:add_child(child_or_args, { auto_start = true })
end

---@return lib.state_machine.state
function State:start_children()
    if #self.children == 0 then
        self:done("children_done")
        return self
    end

    if not self._children_sequence_ready then
        for index = 1, #self.children - 1 do
            self.children[index]:transition_to(self.children[index + 1])
        end
        self.children[#self.children].on_done.add(function()
            if self:is_running() then
                self:done("children_done")
            end
        end)
        self._children_sequence_ready = true
    end

    self.children[1]:start({
        parent = self,
    })
    return self
end

---@param target_or_args lib.state_machine.state|lib.state_machine.state.options
---@param options? { 参数说明
---@return lib.state_machine.state
function State:add_transition(target_or_args, options)
    options = options or {}
    local target = target_or_args
    if not is_state(target_or_args) then
        local args = target_or_args or {}
        args.machine = self.machine
        target = create_state(args)
    elseif target.machine ~= self.machine then
        error("transition target must use the same machine", 2)
    end

    target.previous = self
    self._transitions[#self._transitions + 1] = {
        target = target,
        event = options.event,
        guard = options.guard,
        action = options.action,
    }
    return target
end

---@param target_or_args lib.state_machine.state|lib.state_machine.state.options
---@param options? { 参数说明
---@return lib.state_machine.state
function State:transition_to(target_or_args, options)
    options = options or {}
    options.event = nil
    return self:add_transition(target_or_args, options)
end

---@param args lib.state_machine.state.options
---@return lib.state_machine.state
function State:spawn(args)
    args = args or {}
    args.machine = args.machine or self.machine
    args.parent = nil
    if args.name == nil then
        args.name = self.name .. "_actor"
    end
    local state = create_state(args)
    state:start({
        spawned_by = self,
    })
    return state
end

---@param seconds number
---@param action fun(state:lib.state_machine.state)
---@param options? { 参数说明
---@return fun()
function State:add_timer(seconds, action, options)
    assert(type(seconds) == "number" and seconds >= 0, "seconds must be non-negative number")
    assert(type(action) == "function", "timer action must be function")
    options = options or {}

    local timer = {
        remaining = seconds,
        action = action,
        repeat_interval = options.repeat_interval,
        active = true,
    }
    self._timers[#self._timers + 1] = timer

    local deleted = false
    return function()
        if deleted then
            return
        end
        deleted = true
        timer.active = false
    end
end

---@param event_name string
---@param action fun(state:lib.state_machine.state, ...:any)
---@param options? { 参数说明
---@return fun()
function State:on(event_name, action, options)
    assert(type(event_name) == "string", "event_name must be string")
    assert(type(action) == "function", "event action must be function")
    options = options or {}

    local list = self._event_handlers[event_name]
    if list == nil then
        list = {}
        self._event_handlers[event_name] = list
    end

    local item = {
        action = action,
        once = options.once and true or false,
        guard = options.guard,
        active = true,
    }
    list[#list + 1] = item

    local deleted = false
    return function()
        if deleted then
            return
        end
        deleted = true
        item.active = false
    end
end

---@param event_name string
---@param ... any
---@return lib.state_machine.state
function State:emit(event_name, ...)
    if self._destroyed or self._status ~= "running" then
        return self
    end

    self._hooks.on_event(self, event_name, ...)

    local list = self._event_handlers[event_name]
    if list ~= nil then
        for _, item in ipairs(list) do
            if item.active then
                local ok = item.guard == nil or item.guard(self, ...)
                if ok then
                    item.action(self, ...)
                    if item.once then
                        item.active = false
                    end
                end
            end
        end
    end

    self:_try_transition(event_name, ...)

    local children = {}
    for index, child in ipairs(self.children) do
        children[index] = child
    end
    for _, child in ipairs(children) do
        child:emit(event_name, ...)
    end

    return self
end

---@param event_name string|nil
---@param ... any
---@return boolean
function State:_try_transition(event_name, ...)
    for _, transition in ipairs(self._transitions) do
        if transition.event == event_name then
            local ok = transition.guard == nil or transition.guard(self, ...)
            if ok then
                if event_name ~= nil and self._status == "running" then
                    self._status = "done"
                    self._hooks.on_exit(self, event_name)
                    self.on_done.run(self, event_name)
                end
                if transition.action ~= nil then
                    transition.action(self, transition.target, ...)
                end
                transition.target:start({
                    previous = self,
                    event = event_name,
                    reason = select(1, ...),
                })
                return true
            end
        end
    end
    return false
end

---@param dt number
function State:_update_timers(dt)
    for _, timer in ipairs(self._timers) do
        if timer.active then
            timer.remaining = timer.remaining - dt
            if timer.remaining <= 0 then
                timer.action(self)
                if timer.repeat_interval ~= nil and timer.active then
                    timer.remaining = timer.remaining + timer.repeat_interval
                else
                    timer.active = false
                end
            end
        end
    end
end

return create_state
