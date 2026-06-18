---@class lib.callback.event
---@field type string
---@field mode string

---@class lib.callback.instance
---@field api lib.callback.api
---@field values table

---@class lib.callback.api
---@field type string
---@field name string
---@field _event lib.callback.event

---@class lib.callback
---@field event fun(args?: 字段说明
---@field once_event fun(args?: 字段说明
---@field api fun(args?: 字段说明
---@field set_event_error_handler fun(handler?: 字段说明
---@field set_strict fun(enabled:boolean)
---@field is_strict fun():boolean

---@type fun(err:string, info:table)|nil
local error_handler = nil
local strict = false
local unpack_values = table.unpack or unpack

---@param handler fun(err:string, info:table)|nil
local function set_event_error_handler(handler)
    assert(handler == nil or type(handler) == "function", "event error handler must be a function")
    error_handler = handler
end

---@param enabled boolean
local function set_strict(enabled)
    strict = enabled and true or false
end

---@return boolean
local function is_strict()
    return strict
end

---@param err string
---@param info table
local function report_error(err, info)
    if error_handler == nil then
        print(err)
    else
        local ok, handler_err = xpcall(function()
            error_handler(err, info)
        end, debug.traceback)
        if not ok then
            print(handler_err)
        end
    end

    if strict then
        error(err, 0)
    end
end

---@param err string
---@param info table
local function notify_error(err, info)
    local was_strict = strict
    strict = false
    report_error(err, info)
    strict = was_strict
end

---@param args? { 参数说明
---@return lib.callback.event
local function new_event(args)
    args = args or {}
    local mode = args.mode or "always"
    local replay = args.replay or false
    local name = args.name or ""

    ---@type { action: fun(...)|nil, deleted: boolean }[]
    local subscribers = {}
    local deleted_count = 0
    local running_depth = 0
    local trigger_count = 0
    local has_triggered = false
    ---@type { n: integer, [integer]: any }|nil
    local last_args = nil

    local o = {
        type = "callback.event",
        mode = mode,
    }

    local function compact_subscribers()
        if running_depth > 0 or deleted_count == 0 then
            return
        end
        local compacted = {}
        for _, sub in ipairs(subscribers) do
            if not sub.deleted then
                compacted[#compacted + 1] = sub
            end
        end
        subscribers = compacted
        deleted_count = 0
    end

    local function remove_subscriber(sub)
        if sub == nil or sub.deleted then
            return
        end
        sub.deleted = true
        sub.action = nil
        deleted_count = deleted_count + 1
        if deleted_count > 64 and deleted_count * 2 > #subscribers then
            compact_subscribers()
        end
    end

    local function run_action(action, packed_args, phase)
        local ok, err = xpcall(function()
            action(unpack_values(packed_args, 1, packed_args.n))
        end, debug.traceback)
        if not ok then
            local info = {
                event = o,
                name = name,
                mode = mode,
                phase = phase,
            }
            if strict then
                notify_error(err, info)
            else
                report_error(err, info)
            end
        end
        return ok, err
    end

    function o.get_name()
        return name
    end

    function o.set_name(value)
        name = value or ""
    end

    ---@param action fun(...)
    ---@return fun()
    function o.add(action)
        assert(type(action) == "function", "event action must be a function")
        compact_subscribers()

        local sub = {
            action = action,
            deleted = false,
        }
        subscribers[#subscribers + 1] = sub

        if replay and last_args ~= nil then
            local ok, err = run_action(action, last_args, "replay")
            if mode == "once" or not ok then
                remove_subscriber(sub)
            end
            if strict and not ok then
                error(err, 0)
            end
        end

        local deleted = false
        return function()
            if deleted then
                return
            end
            deleted = true
            remove_subscriber(sub)
        end
    end

    ---@param action fun(...)
    ---@return fun()
    function o.add_and_run(action)
        local unsubscribe = o.add(action)
        local ok, err = xpcall(action, debug.traceback)
        if not ok then
            unsubscribe()
            report_error(err, {
                event = o,
                name = name,
                mode = mode,
                phase = "add_and_run",
            })
        end
        return unsubscribe
    end

    function o.run(...)
        trigger_count = trigger_count + 1
        has_triggered = true

        local packed_args = { n = select("#", ...), ... }
        last_args = packed_args

        local first_err = nil
        local count = #subscribers
        running_depth = running_depth + 1
        for index = 1, count do
            local sub = subscribers[index]
            if sub ~= nil and not sub.deleted and sub.action ~= nil then
                if mode == "once" then
                    local action = sub.action
                    remove_subscriber(sub)
                    local ok, err = run_action(action, packed_args, "run")
                    first_err = first_err or (not ok and err or nil)
                else
                    local ok, err = run_action(sub.action, packed_args, "run")
                    first_err = first_err or (not ok and err or nil)
                end
            end
        end
        running_depth = running_depth - 1
        compact_subscribers()
        if strict and first_err ~= nil then
            error(first_err, 0)
        end
    end

    function o.clear()
        for _, sub in ipairs(subscribers) do
            remove_subscriber(sub)
        end
        subscribers = {}
        deleted_count = 0
        last_args = nil
    end

    function o.has_subscribers()
        for _, sub in ipairs(subscribers) do
            if not sub.deleted then
                return true
            end
        end
        return false
    end

    function o.get_subscriber_count()
        local count = 0
        for _, sub in ipairs(subscribers) do
            if not sub.deleted then
                count = count + 1
            end
        end
        return count
    end

    function o.get_trigger_count()
        return trigger_count
    end

    function o.has_triggered()
        return has_triggered
    end

    function o.as_listener()
        local listener = {}

        function listener.add(action)
            return o.add(action)
        end

        function listener.add_and_run(action)
            return o.add_and_run(action)
        end

        function listener.clear()
            return o.clear()
        end

        function listener.has_subscribers()
            return o.has_subscribers()
        end

        function listener.get_subscriber_count()
            return o.get_subscriber_count()
        end

        function listener.get_trigger_count()
            return o.get_trigger_count()
        end

        function listener.has_triggered()
            return o.has_triggered()
        end

        setmetatable(listener, {
            __call = function(_, action)
                return o.add(action)
            end,
        })

        return listener
    end

    setmetatable(o, {
        __call = function(_, ...)
            o.run(...)
        end,
    })

    return o
end

---@param args? table 参数说明
---@return lib.callback.event
local function once_event(args)
    local copied = {}
    if type(args) == "table" then
        for key, value in pairs(args) do
            copied[key] = value
        end
    end
    copied.mode = "once"
    return new_event(copied)
end

local instance_methods = {}

function instance_methods.emit(self)
    self.api._event.run(self)
    return self
end

function instance_methods.trigger(self)
    return self:emit()
end

function instance_methods.get(self, key)
    return self.values[key]
end

function instance_methods.set(self, key, value)
    assert(key ~= "api" and key ~= "values", "callback instance reserved field cannot be set")
    self.values[key] = value
    return self
end

local instance_metatable = {
    __index = function(self, key)
        if key == "api" then
            return rawget(self, "_api")
        end
        if key == "values" then
            return rawget(self, "_values")
        end
        local method = instance_methods[key]
        if method ~= nil then
            return method
        end
        return rawget(self, "_values")[key]
    end,
    __newindex = function(self, key, value)
        assert(key ~= "api" and key ~= "values", "callback instance reserved field cannot be set")
        self.values[key] = value
    end,
    __tostring = function(self)
        return string.format("<callback.instance %s>", self.api.name)
    end,
}

---@param value any
---@return table
local function copy_values(value)
    local values = {}
    if type(value) ~= "table" then
        return values
    end
    for key, item in pairs(value) do
        values[key] = item
    end
    return values
end

---@param api lib.callback.api
---@param values? table 参数说明
---@return lib.callback.instance
local function new_instance(api, values)
    local copied = copy_values(values)
    local instance = {
        _api = api,
        _values = copied,
    }
    return setmetatable(instance, instance_metatable)
end

local api_methods = {}

function api_methods.new(self, values)
    return new_instance(self, values)
end

function api_methods.register(self, handler)
    return self._event.add(handler)
end

function api_methods.on(self, handler)
    return self:register(handler)
end

function api_methods.emit(self, values)
    if type(values) == "table" and getmetatable(values) == instance_metatable and values.api == self then
        values:emit()
        return values
    end
    return self:new(values):emit()
end

function api_methods.trigger(self, values)
    return self:emit(values)
end

function api_methods.clear(self)
    self._event.clear()
end

function api_methods.has_handlers(self)
    return self._event.has_subscribers()
end

function api_methods.get_handler_count(self)
    return self._event.get_subscriber_count()
end

local api_metatable = {
    __index = api_methods,
    __call = function(self, value)
        if type(value) == "function" then
            return self:register(value)
        end
        return self:emit(value)
    end,
    __tostring = function(self)
        return string.format("<callback.api %s>", self.name)
    end,
}

local M = {
    event = new_event,
    once_event = once_event,
    set_event_error_handler = set_event_error_handler,
    set_strict = set_strict,
    is_strict = is_strict,
}

---@param args? { 参数说明
---@return lib.callback.api
function M.api(args)
    args = args or {}
    local name = args.name or ""
    local api = {
        type = "callback.api",
        name = name,
        _event = new_event({
            name = name,
            replay = args.replay or false,
            mode = args.mode or "always",
        }),
    }
    return setmetatable(api, api_metatable)
end

return M
