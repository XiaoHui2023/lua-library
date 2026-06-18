---事件订阅、触发与删除

local M = {}

---@type fun(err:string, info:table)|nil
local error_handler = nil

---@param handler fun(err:string, info:table)|nil
function M.set_error_handler(handler)
    assert(handler == nil or type(handler) == "function", "event error handler must be a function")
    error_handler = handler
end

---@param err string
---@param info table
local function report_error(err, info)
    if error_handler ~= nil then
        local ok, handler_err = xpcall(function()
            error_handler(err, info)
        end, debug.traceback)
        if ok then
            return
        end
        print(handler_err)
        return
    end
    print(err)
end

---@class lib.reactive.event<T>
---@field type "event" 事件类型标记
---@field mode string 触发模式
---@field add fun(action:function):function 添加监听并返回取消函数
---@field add_and_run fun(action:function):function 添加监听后立即运行一次
---@field run fun(...:any) 触发事件
---@field clear fun() 清空监听
---@field attach fun(item:function|table):function 挂载函数或可释放对象
---@field mount fun(item:function|table):function 挂载函数或可释放对象
---@field as_listener fun():table 返回只暴露监听能力的对象

---@param args? table 事件配置
---@return lib.reactive.event
function M.new(args)
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
        type = "event",
        mode = mode,
    }

    function o.get_name()
        return name
    end

    function o.set_name(value)
        name = value or ""
    end

    local function compact_subscribers()
        if running_depth > 0 or deleted_count == 0 then
            return
        end
        local compacted = {}
        for _, sub in ipairs(subscribers) do
            if not sub.deleted then
                table.insert(compacted, sub)
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
            action(table.unpack(packed_args, 1, packed_args.n))
        end, debug.traceback)
        if not ok then
            report_error(err, {
                event = o,
                name = name,
                mode = mode,
                phase = phase,
            })
        end
        return ok
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
            local ok = run_action(action, last_args, "replay")
            if mode == "once" or not ok then
                remove_subscriber(sub)
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

    ---@param ... any
    function o.run(...)
        trigger_count = trigger_count + 1
        has_triggered = true
        last_args = { n = select("#", ...), ... }

        local count = #subscribers
        running_depth = running_depth + 1
        local args = { n = select("#", ...), ... }
        for index = 1, count do
            local sub = subscribers[index]
            if not sub.deleted and sub.action ~= nil then
                if mode == "once" then
                    local action = sub.action
                    remove_subscriber(sub)
                    run_action(action, args, "run")
                else
                    run_action(sub.action, args, "run")
                end
            end
        end
        running_depth = running_depth - 1

        compact_subscribers()
    end

    function o.clear()
        for _, sub in ipairs(subscribers) do
            remove_subscriber(sub)
        end
        subscribers = {}
        deleted_count = 0
        last_args = nil
    end

    function o.attach(item)
        if type(item) == "function" then
            return o.add(item)
        end
        if type(item) == "table" then
            return o.add(function()
                if item.dispose ~= nil then
                    item.dispose()
                elseif item.delete ~= nil then
                    item.delete()
                elseif item.clear ~= nil then
                    item.clear()
                else
                    item()
                end
            end)
        end
        return function() end
    end

    function o.mount(item)
        return o.attach(item)
    end

    function o.has_subscribers()
        for _, sub in ipairs(subscribers) do
            if not sub.deleted then
                return true
            end
        end
        return false
    end

    function o.get_trigger_count()
        return trigger_count
    end

    function o.has_triggered()
        return has_triggered
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

        function listener.attach(item)
            return o.attach(item)
        end

        function listener.mount(item)
            return o.mount(item)
        end

        function listener.has_subscribers()
            return o.has_subscribers()
        end

        function listener.get_trigger_count()
            return o.get_trigger_count()
        end

        function listener.has_triggered()
            return o.has_triggered()
        end

        function listener.get_subscriber_count()
            return o.get_subscriber_count()
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

---@param args? table 一次性事件配置
---@return lib.reactive.event
function M.once(args)
    args = args or {}
    args.mode = "once"
    return M.new(args)
end

return M
