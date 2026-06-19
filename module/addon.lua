---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.reactive
local reactive = require "lib.reactive"
---@type fun(tb?: any[]): lib.list<any>
local list = require "lib.list"
---@type lib.module.order
local module_path = (...):match("^(.*)%.[^.]+$") or "module"
local order = require(module_path .. ".order")

---@class lib.module.addon
---@operator call(...): lib.module.addon
local M = {}

M.PRIORITY = {
    MODELS = -100,
    NORMAL = 0,
}

---@type lib.module.addon[]
local ADDONS = {}

---@type table<string, lib.module.addon>
local ID_TO_ADDON = {}

local next_order_id = 1

---@param addon lib.module.addon
---@param dependency any
---@return lib.module.addon
local function resolve_dependency(addon, dependency)
    if type(dependency) == "string" then
        local resolved = ID_TO_ADDON[dependency]
        assert(resolved ~= nil, "addon<" .. addon.id .. "> dependency not registered: " .. dependency)
        return resolved
    end
    assert(type(dependency) == "table" and dependency.__module_kind == "addon", "addon<" .. addon.id .. "> dependency must be an addon or id")
    return dependency
end

---@return lib.list<lib.module.addon>
function M.get_addons()
    return list(order.sort(ADDONS, {
        type_name = "addon",
        dependencies = function(addon)
            return addon.dependencies
        end,
        resolve = resolve_dependency,
    }))
end

---@param id string
---@return lib.module.addon?
function M.get(id)
    return ID_TO_ADDON[id]
end

---@param func fun(addon: lib.module.addon): nil
function M.for_each(func)
    M.get_addons().for_each(func)
end

function M.initialize_all()
    M.for_each(function(addon)
        addon.initialize()
    end)
end

---@class lib.module.addon.options : lib.reactive.factory.options
---@field id? string
---@field name string
---@field description? string
---@field dependencies? (string|lib.module.addon)[]
---@field tags? string[]
---@field category? string
---@field is_enabled? boolean
---@field is_unlocked? boolean
---@field is_visible? boolean
---@field priority? integer

---@param args lib.module.addon.options
---@return lib.module.addon
function M.register(args)
    assert(type(args) == "table", "addon.register requires options")
    assert(type(args.name) == "string" and args.name ~= "", "addon name must be a non-empty string")

    args.id = args.id or args.name
    assert(type(args.id) == "string" and args.id ~= "", "addon id must be a non-empty string")
    assert(ID_TO_ADDON[args.id] == nil, "duplicate addon id: " .. args.id)

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

    ---@class lib.module.addon: lib.reactive.factory
    local addon = reactive.factory(args)
    addon.set_class("addon")
    addon.__module_kind = "addon"
    addon.id = args.id
    addon.order_id = next_order_id
    next_order_id = next_order_id + 1

    addon.dependencies = args.dependencies
    addon.tags = args.tags
    addon.to_dependency = {}
    for _, dependency in ipairs(addon.dependencies) do
        if type(dependency) == "table" then
            addon.to_dependency[dependency] = true
        end
    end

    addon.priority = reactive.ref(args.priority)
    addon.is_enabled = reactive.ref(args.is_enabled)
    addon.is_visible = reactive.ref(args.is_visible)
    addon.description = reactive.ref(args.description)
    addon.category = reactive.ref(args.category)
    addon.is_unlocked = reactive.ref(args.is_unlocked)
    addon.has_initialized = reactive.ref(false)

    local on_activate = reactive.event({ name = args.id .. ".activate" })
    local once_deactivate = reactive.once_event({ name = args.id .. ".deactivate_once" })
    local on_initialize = reactive.event({ name = args.id .. ".initialize" })
    local on_deactivate = reactive.event({ name = args.id .. ".deactivate" })

    addon.on_activate = on_activate.as_listener()
    addon.once_deactivate = once_deactivate.as_listener()
    addon.on_initialize = on_initialize.as_listener()
    addon.on_deactivate = on_deactivate.as_listener()

    addon.is_active = reactive.computed(function()
        if not addon.has_initialized() then
            return false
        end
        if not addon.is_enabled() then
            return false
        end
        if not addon.is_unlocked() then
            return false
        end
        for _, dependency in ipairs(addon.dependencies) do
            if not resolve_dependency(addon, dependency).is_active() then
                return false
            end
        end
        return true
    end)

    local was_active = false
    addon.is_active.on_update.add(function(active)
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

    addon.is_active.auto_update()

    function addon.initialize()
        if addon.has_initialized() then
            addon.is_active.try_update()
            return
        end
        on_initialize.run()
        addon.has_initialized.set(true)
        addon.is_active.try_update()
    end

    ---@param func fun(): lib.reactive.once_event|fun(): nil
    function addon.bind_activation(func)
        on_activate.add(function()
            once_deactivate.attach(func())
        end)
    end

    ---@param expr fun(): ...
    ---@return lib.reactive.computed
    function addon.create_frame_update_computed(expr)
        local computed = reactive.computed(expr)
        computed.auto_update()
        return computed
    end

    metatablex.lock_new_fields(addon.dependencies)
    metatablex.lock_new_fields(addon.tags)
    metatablex.lock_new_fields(addon.to_dependency)

    ADDONS[#ADDONS + 1] = addon
    ID_TO_ADDON[addon.id] = addon

    return addon
end

metatablex.callable(M, M.register)

return M
