---Reactive object factory base.

local event = require "reactive.event"
local ref = require "reactive.ref"
local list_ref = require "reactive.list_ref"
local table_ref = require "reactive.table_ref"
local computed = require "reactive.computed"
local semaphore = require "reactive.semaphore"
local scope = require "reactive.scope"
local collection = require "reactive.collection"
local timer = require "reactive.timer"

local M = {}

local FACTORY_FIELD = "factory"

---@class lib.reactive.factory
---@field _is_reactive_factory boolean 响应式工厂标记
---@field owner table 拥有该工厂的对象
---@field name lib.reactive.ref 工厂短名称
---@field parent lib.reactive.ref 父对象引用
---@field full_name lib.reactive.computed 完整名称
---@field children table<string, table> 已捕获的子对象
---@field on_dispose table 销毁监听器
---@field set fun(...:any):lib.reactive.ref 创建响应式引用
---@field ref fun(args?:table):lib.reactive.ref 创建响应式引用
---@field add fun(args?:table):lib.reactive.collection 创建响应式集合
---@field computed fun(args:table|function):lib.reactive.computed 创建计算值
---@field event fun(args?:table):lib.reactive.event 创建普通事件
---@field once_event fun(args?:table):lib.reactive.event 创建一次性事件
---@field semaphore fun(args?:table):lib.reactive.semaphore 创建信号量
---@field scope fun(args?:table):table 创建释放作用域

---@class lib.reactive.factory.options
---@field name? string 工厂名称
---@field parent? table 父对象
---@field debug? boolean 是否打印调试信息
---@field interval_time? number 默认定时器间隔，单位秒

---@param loop_func? fun(func:function, interval_time:number) 循环调度函数
---@param interval_time? number 循环间隔，单位秒
function M.set_timer_loop(loop_func, interval_time)
    timer.set_loop(loop_func, interval_time)
end

---@param driver? table|fun(trigger:function, interval_time:number) 定时器驱动
---@param interval_time? number 定时器间隔，单位秒
function M.set_timer_driver(driver, interval_time)
    timer.set_driver(driver, interval_time)
end

---@param value any
---@return table|nil
local function get_factory(value)
    if type(value) ~= "table" then
        return nil
    end
    local factory = rawget(value, FACTORY_FIELD)
    if type(factory) == "table" and factory._is_reactive_factory then
        return factory
    end
    if rawget(value, "_is_reactive_factory") then
        return value
    end
    return nil
end

---@param model table
---@return boolean
local function is_disposable(model)
    return type(model) == "table" and (model.dispose ~= nil or model.clear ~= nil)
end

---@param model table
local function dispose_model(model)
    if model.dispose ~= nil then
        model.dispose()
    elseif model.clear ~= nil then
        model.clear()
    end
end

---@param owner table
---@param args? table 绑定工厂配置
---@return table
local function attach(owner, args)
    args = args or {}

    local debug_enabled = args.debug or false
    local disposed = false
    local captured = {}
    local dispose_bound = {}
    local pending = setmetatable({}, { __mode = "k" })
    local children = {}
    local storage = {}
    local name_ref = ref.new({
        value = args.name or "",
        name = "factory.name",
    })
    local parent_ref = ref.new({
        value = nil,
        name = "factory.parent",
    })
    local on_dispose = event.new({
        mode = "once",
        name = (args.name or "") .. ".dispose",
    })

    local factory = {
        _is_reactive_factory = true,
        type = "factory",
        owner = owner,
        name = name_ref,
        parent = parent_ref,
        children = children,
        on_dispose_event = on_dispose,
        on_dispose = on_dispose.as_listener(),
    }
    rawset(owner, FACTORY_FIELD, factory)

    owner.class_name = owner.class_name or "factory"

    function owner.set_class(class_name)
        owner.class_name = class_name
    end

    function owner.is_instance_of(value, class_name)
        return type(value) == "table" and (value.class_name == class_name or value.type == class_name)
    end

    factory.full_name = computed.new({
        name = "factory.full_name",
        auto = true,
        expr = function()
            local parent = parent_ref()
            local parent_factory = get_factory(parent)
            local name = name_ref()
            if parent_factory ~= nil then
                local parent_name = parent_factory.get_full_name()
                if parent_name ~= "" and name ~= "" then
                    return parent_name .. "." .. name
                end
                if parent_name ~= "" then
                    return parent_name
                end
            end
            return name
        end,
    })

    local function debug_log(message)
        if debug_enabled then
            print(string.format("[%s] %s", factory.get_full_name(), message))
        end
    end

    local function normalize_args(first, second)
        if first == factory then
            return second or {}
        end
        return first or {}
    end

    local function normalize_value(first, second, third)
        if first == factory then
            return second, third or {}
        end
        return first, second or {}
    end

    local function child_name(field_name)
        local prefix = factory.get_full_name()
        if field_name == nil or field_name == "" then
            return prefix
        end
        if prefix ~= "" then
            return prefix .. "." .. field_name
        end
        return field_name
    end

    local function apply_name(model, field_name)
        if type(field_name) ~= "string" or field_name == "" then
            return
        end

        local child_factory = get_factory(model)
        if child_factory ~= nil then
            if child_factory.name() == "" then
                child_factory.set_name(field_name)
            end
            return
        end

        if type(model) == "table" and model.set_name ~= nil then
            model.set_name(child_name(field_name))
        end
    end

    local function bind_dispose(model)
        if dispose_bound[model] then
            return
        end
        dispose_bound[model] = true
        on_dispose.add(function()
            dispose_model(model)
        end)
    end

    local function add_child(factory_child)
        if factory_child.parent() ~= owner then
            factory_child.set_parent(owner)
        end
        on_dispose.add(function()
            factory_child.dispose()
        end)
    end

    function factory.get_name()
        return name_ref()
    end

    function factory.set_name(name)
        name_ref.set(name or "")
        factory.refresh_names()
    end

    function factory.get_full_name()
        return factory.full_name()
    end

    function factory.get_parent()
        return parent_ref()
    end

    function factory.set_parent(parent)
        parent_ref.set(parent)
    end

    function factory.refresh_names()
        for field_name, model in pairs(children) do
            apply_name(model, field_name)
            local child_factory = get_factory(model)
            if child_factory ~= nil then
                child_factory.refresh_names()
            end
        end
    end

    function factory.capture(field_name, model)
        if field_name == FACTORY_FIELD then
            return model
        end
        if field_name ~= nil and field_name ~= "" then
            children[field_name] = nil
        end
        if model == nil then
            return model
        end

        local child_factory = get_factory(model)
        if child_factory ~= nil then
            if captured[model] ~= nil then
                if field_name ~= nil and field_name ~= "" then
                    children[field_name] = model
                end
                apply_name(model, field_name)
                return model
            end
            captured[model] = field_name
            if field_name ~= nil and field_name ~= "" then
                children[field_name] = model
            end
            add_child(child_factory)
            apply_name(model, field_name)
            debug_log(string.format("capture child %s", tostring(field_name)))
            return model
        end

        if not pending[model] and not is_disposable(model) then
            return model
        end
        if captured[model] ~= nil then
            if field_name ~= nil and field_name ~= "" then
                children[field_name] = model
                apply_name(model, field_name)
            end
            return model
        end

        captured[model] = field_name
        if field_name ~= nil and field_name ~= "" then
            children[field_name] = model
            apply_name(model, field_name)
            debug_log(string.format("capture %s", tostring(field_name)))
        end
        if is_disposable(model) then
            bind_dispose(model)
        end
        return model
    end

    function factory.register(model, field_name)
        pending[model] = true
        if field_name ~= nil and field_name ~= "" then
            factory.capture(field_name, model)
        elseif is_disposable(model) then
            bind_dispose(model)
        end
        return model
    end

    function factory.ref(first, second)
        local args = normalize_args(first, second)
        return factory.register(ref.new(args), args.name)
    end

    function factory.set(...)
        local values = { n = select("#", ...), ... }
        if values[1] == factory then
            table.remove(values, 1)
            values.n = values.n - 1
        end
        local args = {
            values = values,
        }
        return factory.register(ref.new(args), args.name)
    end

    function factory.list_ref(first, second)
        local args = normalize_args(first, second)
        return factory.register(list_ref.new(args), args.name)
    end

    function factory.table_ref(first, second)
        local args = normalize_args(first, second)
        return factory.register(table_ref.new(args), args.name)
    end

    function factory.list(first, second)
        return factory.list_ref(first, second)
    end

    function factory.add(first, second)
        local args = normalize_args(first, second)
        return factory.register(collection.new(args), args.name)
    end

    function factory.table(first, second)
        return factory.table_ref(first, second)
    end

    function factory.map(first, second)
        return factory.table_ref(first, second)
    end

    function factory.computed(first, second)
        local args = normalize_args(first, second)
        if type(args) == "function" then
            args = { expr = args }
        end
        return factory.register(computed.new(args), args.name)
    end

    function factory.frame_computed(first, second)
        local args = normalize_args(first, second)
        if type(args) == "function" then
            args = { expr = args }
        end
        args.flush = "frame"
        return factory.register(computed.new(args), args.name)
    end

    function factory.sync_computed(first, second)
        local args = normalize_args(first, second)
        if type(args) == "function" then
            args = { expr = args }
        end
        args.flush = "sync"
        return factory.register(computed.new(args), args.name)
    end

    function factory.event(first, second)
        local args = normalize_args(first, second)
        args.mode = "always"
        return factory.register(event.new(args), args.name)
    end

    function factory.once_event(first, second)
        local args = normalize_args(first, second)
        return factory.register(event.once(args), args.name)
    end

    function factory.semaphore(first, second)
        local args = normalize_args(first, second)
        return factory.register(semaphore.new(args), args.name)
    end

    function factory.scope(first, second)
        local args = normalize_args(first, second)
        return factory.register(scope.new(args), args.name)
    end

    function factory.delete(first, second)
        return factory.scope(first, second)
    end

    function factory.register_hook_fields()
        factory.refresh_names()
    end

    function factory.child(first, second)
        local args = normalize_args(first, second)
        args.parent = owner
        local child = M.new(args)
        return factory.register(child, args.name)
    end

    owner.name = factory.name
    owner.full_name = factory.full_name
    owner.delete = factory.scope({ name = "delete" })

    factory.timer = {}
    factory.timer.interval_time = factory.set(args.interval_time or timer.get_default_interval_time())
    factory.interval_time = factory.timer.interval_time

    local function normalize_timer_args(func, interval_or_scope, delete_scope)
        local interval_time = factory.timer.interval_time()
        if type(interval_or_scope) == "number" then
            interval_time = interval_or_scope
        elseif interval_or_scope ~= nil then
            delete_scope = interval_or_scope
        end
        return func, interval_time, delete_scope
    end

    function factory.timer.loop(func, interval_or_scope, delete_scope)
        local action, interval_time, scope_model = normalize_timer_args(func, interval_or_scope, delete_scope)
        local timer_model = factory.register(timer.new({
            action = action,
            interval_time = interval_time,
            name = "timer",
        }))
        if scope_model ~= nil and scope_model.add ~= nil then
            scope_model.add(timer_model)
        end
        return timer_model
    end

    factory.interval = factory.timer.loop

    setmetatable(factory.timer, {
        __call = function(_, ...)
            return factory.timer.loop(...)
        end,
    })

    function factory.dispose()
        if disposed then
            return
        end
        disposed = true
        on_dispose.run()
        on_dispose.clear()
        factory.full_name.dispose()
        parent_ref.dispose()
        name_ref.dispose()
        children = {}
        factory.children = children
    end

    function factory.is_disposed()
        return disposed
    end

    name_ref.on_change(function()
        factory.refresh_names()
    end)

    parent_ref.on_change(function()
        factory.refresh_names()
    end)

    local old_metatable = getmetatable(owner) or {}
    for key, value in pairs(owner) do
        if key ~= FACTORY_FIELD then
            storage[key] = value
            rawset(owner, key, nil)
        end
    end

    local old_index = old_metatable.__index
    local old_newindex = old_metatable.__newindex
    local metatable = {}
    for key, value in pairs(old_metatable) do
        metatable[key] = value
    end
    metatable.__index = function(t, key)
        local value = storage[key]
        if value ~= nil then
            return value
        end
        if old_index == nil then
            return nil
        end
        if type(old_index) == "function" then
            return old_index(t, key)
        end
        return old_index[key]
    end
    metatable.__newindex = function(t, key, value)
        if key == FACTORY_FIELD then
            rawset(t, key, value)
            return
        end
        if old_newindex ~= nil then
            if type(old_newindex) == "function" then
                old_newindex(t, key, value)
            else
                old_newindex[key] = value
            end
        end
        storage[key] = value
        factory.capture(key, value)
    end
    metatable.__pairs = function()
        local yielded = {}
        local old_iter
        local old_state
        local old_key

        if old_metatable.__pairs ~= nil then
            old_iter, old_state, old_key = old_metatable.__pairs(owner)
        end

        return function()
            if old_iter ~= nil then
                local key, value = old_iter(old_state, old_key)
                old_key = key
                if key ~= nil then
                    yielded[key] = true
                    return key, value
                end
                old_iter = nil
            end

            local key, value = next(storage)
            while key ~= nil and yielded[key] do
                key, value = next(storage, key)
            end
            if key ~= nil then
                yielded[key] = true
                return key, value
            end
            return nil
        end
    end
    metatable.__tostring = metatable.__tostring or function()
        return string.format("<factory %s>", factory.get_full_name())
    end
    setmetatable(owner, metatable)

    for key, value in pairs(storage) do
        factory.capture(key, value)
    end

    if args.parent ~= nil then
        local parent_factory = get_factory(args.parent)
        if parent_factory ~= nil then
            parent_factory.capture(args.name or "", owner)
        else
            factory.set_parent(args.parent)
        end
    end

    return factory
end

---@param args? lib.reactive.factory.options 工厂配置
---@return table
function M.new(args)
    local owner = {}
    attach(owner, args)
    return owner
end

---@param owner table
---@param args? lib.reactive.factory.options 工厂配置
---@return table
function M.attach(owner, args)
    assert(type(owner) == "table", "factory.attach requires owner table")
    if get_factory(owner) ~= nil then
        return owner
    end
    attach(owner, args)
    return owner
end

return M
