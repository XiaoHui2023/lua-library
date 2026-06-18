
local reactive_base = require "reactive.base"
local event = require "reactive.event"
local track = require "reactive.track"

local M = {}

local function pack_values(...)
    return {
        n = select("#", ...),
        ...
    }
end

local function unpack_values(values)
    return table.unpack(values, 1, values.n or #values)
end

local function values_equal(new_values, old_values, equals)
    local new_count = new_values.n or #new_values
    local old_count = old_values.n or #old_values
    if new_count ~= old_count then
        return false
    end
    for index = 1, new_count do
        if not equals(new_values[index], old_values[index]) then
            return false
        end
    end
    return true
end

local function concat_values(first, second)
    local first_count = first.n or #first
    local second_count = second.n or #second
    local result = { n = first_count + second_count }
    for index = 1, first_count do
        result[index] = first[index]
    end
    for index = 1, second_count do
        result[first_count + index] = second[index]
    end
    return result
end

---@class lib.reactive.ref<T>
---@field type "ref" 响应式引用类型标记
---@field on_change table 值变化监听器
---@field on_set table 写入监听器
---@field on_dispose table 销毁监听器
---@field on_track table 读取追踪监听器
---@field raw_get fun():... 读取当前值且不记录依赖
---@field get fun():... 读取当前值并记录依赖
---@field set fun(...:any) 写入新值
---@field normalize fun(func:function):lib.reactive.ref 设置写入前的规范化函数
---@field wrap_set fun(func:function):lib.reactive.ref 设置写入前的规范化函数
---@field equal fun(func:function):lib.reactive.ref 设置相等判断函数
---@field wrap_equal fun(func:function):lib.reactive.ref 设置相等判断函数
---@field watch fun(action:function, options?:table):function 监听值变化并返回取消函数
---@field dispose fun() 销毁引用和监听器

---@param args? table 引用初始值和校验配置
---@return lib.reactive.ref
function M.new(args, ...)
    if args == nil then
        args = {}
    elseif type(args) ~= "table" or (args.value == nil and args.values == nil and args.equals == nil and args.checker == nil and args.normalize == nil and args.readonly == nil and args.name == nil) then
        args = {
            values = pack_values(args, ...),
        }
    end
    local values
    if args.values ~= nil then
        values = pack_values(table.unpack(args.values, 1, args.values.n or #args.values))
    else
        values = pack_values(args.value)
    end
    local equals = args.equals or function(a, b)
        return a == b
    end
    local checker = args.checker
    local normalize = args.normalize
    local readonly = args.readonly or false
    local always_dirty = false

    local base = reactive_base.new({ name = args.name or "" })
    local on_change = event.new({ name = (args.name or "") .. ".change" })
    local on_set = event.new({ name = (args.name or "") .. ".set" })
    local on_dispose = event.new({ mode = "once", name = (args.name or "") .. ".dispose" })
    local on_track = event.new({ name = (args.name or "") .. ".track" })

    local o = {
        type = "ref",
        on_dispose = on_dispose.as_listener(),
        on_track = on_track.as_listener(),
    }

    o.on_change = on_change.as_listener()
    local add_on_change = o.on_change.add
    function o.on_change.add(action)
        local unsubscribe = add_on_change(action)
        action(unpack_values(values))
        return unsubscribe
    end

    o.on_set = on_set.as_listener()
    local add_on_set = o.on_set.add
    function o.on_set.add(action)
        local unsubscribe = add_on_set(action)
        action(unpack_values(values))
        return unsubscribe
    end

    function o.get_name()
        return base.get_name()
    end

    function o.set_name(name)
        base.set_name(name)
    end

    function o.get_version()
        return base.get_version()
    end

    function o.is_disposed()
        return base.is_disposed()
    end

    function o.is_dirty()
        return always_dirty
    end

    local function normalize_values(...)
        if normalize == nil then
            return pack_values(...)
        end
        return pack_values(normalize(...))
    end

    function o.raw_get()
        return unpack_values(values)
    end

    function o.get()
        o.track()
        local current_values = pack_values(o.raw_get())
        on_track.run(unpack_values(current_values))
        return unpack_values(current_values)
    end

    function o.set(...)
        if base.is_disposed() then
            return
        end
        if readonly then
            error(string.format("ref<%s> is readonly", o.get_name()))
        end
        local new_values = normalize_values(...)
        for index = 1, new_values.n or #new_values do
            local new_value = new_values[index]
            if checker ~= nil and not checker(new_value) then
                error(string.format("ref<%s> value check failed: %s", o.get_name(), tostring(new_value)))
            end
        end
        local old_values = values
        values = new_values
        local event_values = concat_values(new_values, old_values)
        on_set.run(unpack_values(event_values))
        if not values_equal(new_values, old_values, equals) then
            base.touch()
            on_change.run(unpack_values(event_values))
        end
    end

    function o.normalize(func)
        assert(type(func) == "function", "ref normalize must be a function")
        normalize = func
        o.set(unpack_values(values))
        return o
    end

    function o.wrap_set(func)
        return o.normalize(func)
    end

    function o.equal(func)
        assert(type(func) == "function", "ref equal must be a function")
        equals = func
        return o
    end

    function o.wrap_equal(func)
        return o.equal(func)
    end

    function o.override_raw_get(func)
        assert(type(func) == "function", "ref raw getter override must be a function")
        o.raw_get = function()
            return func()
        end
        always_dirty = true
        base.touch()
        on_change.run(o.raw_get())
        return o
    end

    function o.override(method_name, wrapper)
        assert(method_name == "set", "ref only supports overriding set")
        assert(type(wrapper) == "function", "ref override wrapper must be a function")
        local old_set = o.set
        o.set = function(...)
            return wrapper(o, old_set, ...)
        end
        return o
    end

    function o.watch(action, options)
        options = options or {}
        local unsubscribe = on_change.add(action)
        if options.immediate then
            action(unpack_values(values))
        end
        return unsubscribe
    end

    function o.track()
        if base.is_disposed() then
            return
        end
        track.register(o)
    end

    function o.dispose()
        if base.is_disposed() then
            return
        end
        on_dispose.run()
        on_change.clear()
        on_set.clear()
        on_track.clear()
        on_dispose.clear()
        base.mark_disposed()
    end

    setmetatable(o, {
        __call = function()
            return o.get()
        end,
    })

    return o
end

return M
