---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.reactive
local reactive = require "lib.reactive"
---@type fun(tb?: any[]): lib.list<any>
local list = require "lib.list"

---@class lib.addon
---@operator call(...): lib.addon
local M = {}

---@class lib.addon.priority
M.PRIORITY = {
    MODELS = -100,
    NORMAL = 0,
}

---@type lib.reactive.add<lib.addon>
local ADDONS = reactive.collection({
    type_checker = function(element)
        return reactive.is_instance_of(element, "addon")
    end,
    prevent_duplicate = true,
})

---@param value any
---@return boolean
local function is_addon(value)
    return reactive.is_instance_of(value, "addon")
end

---@param addon lib.addon
---@return string
local function addon_name(addon)
    if addon ~= nil and addon.name ~= nil then
        return tostring(addon.name())
    end
    return tostring(addon)
end

---@param a lib.addon
---@param b lib.addon
---@return boolean
local function addon_less(a, b)
    local a_priority = a.priority()
    local b_priority = b.priority()
    if a_priority ~= b_priority then
        return a_priority < b_priority
    end
    return a.id < b.id
end

---@param addons lib.addon[]
local function sort_addon_array(addons)
    table.sort(addons, addon_less)
end

---@param addon lib.addon
---@param dependency any
local function assert_dependency(addon, dependency)
    assert(is_addon(dependency), string.format(
        "addon<%s> dependency must be an addon: %s",
        addon_name(addon),
        tostring(dependency)
    ))
end

---@param path lib.addon[]
---@param repeated lib.addon
---@return string
local function format_cycle(path, repeated)
    local parts = {}
    local should_collect = false
    for _, addon in ipairs(path) do
        if addon == repeated then
            should_collect = true
        end
        if should_collect then
            parts[#parts + 1] = addon_name(addon)
        end
    end
    parts[#parts + 1] = addon_name(repeated)
    return table.concat(parts, " -> ")
end

---@param addons lib.list<lib.addon>
---@return lib.list<lib.addon>
local function order_addons(addons)
    local roots = addons.to_table()
    sort_addon_array(roots)

    ---@type lib.addon[]
    local ordered = {}
    ---@type table<lib.addon, boolean>
    local visited = {}
    ---@type table<lib.addon, boolean>
    local visiting = {}
    ---@type lib.addon[]
    local path = {}

    ---@param addon lib.addon
    local function visit(addon)
        if visited[addon] then
            return
        end
        if visiting[addon] then
            error("addon dependency cycle: " .. format_cycle(path, addon))
        end

        visiting[addon] = true
        path[#path + 1] = addon

        local dependencies = {}
        for _, dependency in ipairs(addon.dependencies) do
            assert_dependency(addon, dependency)
            dependencies[#dependencies + 1] = dependency
        end
        sort_addon_array(dependencies)
        for _, dependency in ipairs(dependencies) do
            visit(dependency)
        end

        path[#path] = nil
        visiting[addon] = nil
        visited[addon] = true
        ordered[#ordered + 1] = addon
    end

    for _, addon in ipairs(roots) do
        visit(addon)
    end

    return list(ordered)
end

---@return lib.list<lib.addon>
function M.get_addons()
    return order_addons(ADDONS.get())
end

---@param func fun(addon: lib.addon): nil
function M.for_each(func)
    M.get_addons().for_each(func)
end

function M.initialize_all()
    M.for_each(function(addon_instance)
        addon_instance.initialize()
    end)
end

---@type integer
local next_id = 1

---@class lib.addon.options : lib.reactive.factory.options
---@field name string
---@field description? string 插件说明文本
---@field dependencies? lib.addon[] 当前插件依赖的其它插件
---@field tags? string[] 插件标签列表
---@field category? string 插件分类名
---@field is_enabled? boolean 初始启用状态，省略时启用
---@field is_unlocked? boolean 初始解锁状态，省略时解锁
---@field is_visible? boolean 初始可见状态，省略时隐藏
---@field priority? integer 初始化排序优先级，数值越小越靠前

---@param args lib.addon.options
---@return lib.addon
function M.register(args)
    assert(type(args) == "table", "addon.register requires options")
    assert(type(args.name) == "string" and args.name ~= "", "addon name must be a non-empty string")

    args.description = args.description or ""
    args.dependencies = args.dependencies or {}
    args.tags = args.tags or {}
    args.category = args.category or ""
    if args.is_enabled == nil then
        args.is_enabled = true
    end
    if args.is_unlocked == nil then
        args.is_unlocked = true
    end
    if args.is_visible == nil then
        args.is_visible = false
    end
    args.priority = args.priority or M.PRIORITY.NORMAL

    ---@class lib.addon: lib.reactive.factory
    local o = reactive.factory(args)
    o.set_class("addon")

    ---@type lib.addon[]
    o.dependencies = args.dependencies
    for _, dependency in ipairs(o.dependencies) do
        assert_dependency(o, dependency)
    end

    ---@type string[]
    o.tags = args.tags

    ---@type table<lib.addon, boolean>
    o.to_dependency = {}
    for _, dependency in ipairs(o.dependencies) do
        o.to_dependency[dependency] = true
    end

    ---@type lib.reactive.set<integer>
    o.priority = reactive.ref(args.priority)

    ---@type lib.reactive.set<boolean>
    o.is_enabled = reactive.ref(args.is_enabled)

    ---@type lib.reactive.set<boolean>
    o.is_visible = reactive.ref(args.is_visible)

    ---@type lib.reactive.set<string>
    o.description = reactive.ref(args.description)

    ---@type lib.reactive.set<string>
    o.category = reactive.ref(args.category)

    ---@type lib.reactive.set<boolean>
    o.is_unlocked = reactive.ref(args.is_unlocked)

    ---@type lib.reactive.set<boolean>
    o.has_initialized = reactive.ref(false)

    local on_activate = reactive.event({ name = args.name .. ".activate" })
    local once_deactivate = reactive.once_event({ name = args.name .. ".deactivate_once" })
    local on_initialize = reactive.event({ name = args.name .. ".initialize" })
    local on_deactivate = reactive.event({ name = args.name .. ".deactivate" })

    ---@type lib.reactive.event
    o.on_activate = on_activate.as_listener()

    ---@type lib.reactive.once_event
    o.once_deactivate = once_deactivate.as_listener()

    ---@type lib.reactive.event
    o.on_initialize = on_initialize.as_listener()

    ---@type lib.reactive.event
    o.on_deactivate = on_deactivate.as_listener()

    ---@type lib.reactive.computed<boolean>
    o.is_active = reactive.computed(function()
        if not o.has_initialized() then
            return false
        end
        if not o.is_enabled() then
            return false
        end
        if not o.is_unlocked() then
            return false
        end
        for _, dependency in ipairs(o.dependencies) do
            if not dependency.is_active() then
                return false
            end
        end
        return true
    end)

    local was_active = false
    o.is_active.on_update.add(function(active)
        if active == was_active then
            return
        end
        was_active = active
        if active then
            on_activate.run()
        else
            on_deactivate.run()
            once_deactivate.run()
        end
    end)

    o.is_active.auto_update()

    function o.initialize()
        if o.has_initialized() then
            o.is_active.try_update()
            return
        end
        on_initialize.run()
        o.has_initialized.set(true)
        o.is_active.try_update()
    end

    ---@param func fun(): lib.reactive.once_event|fun(): nil
    function o.bind_activation(func)
        on_activate.add(function()
            once_deactivate.attach(func())
        end)
    end

    ---@param expr fun(): ...
    ---@return lib.reactive.computed
    function o.create_frame_update_computed(expr)
        ---@type lib.reactive.computed
        local computed = reactive.computed(expr)
        computed.auto_update()
        return computed
    end

    metatablex.lock_new_fields(o.dependencies)
    metatablex.lock_new_fields(o.tags)
    metatablex.lock_new_fields(o.to_dependency)

    ---@type integer
    o.id = next_id
    next_id = next_id + 1

    ADDONS.add(o)

    return o
end

metatablex.callable(M, M.register)

return M
