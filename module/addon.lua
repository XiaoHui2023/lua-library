---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.reactive
local reactive = require "lib.reactive"
---@type fun(tb?: any[]): lib.list<any>
local list = require "lib.list"
local module_path = (...):match("^(.*)%.[^.]+$") or "module"
---@type lib.module.base
local base = require(module_path .. ".base")

---@class lib.module.addon.registry: lib.module.base.registry
---@operator call(lib.module.addon.options): lib.module.addon
---@field PRIORITY table<string, integer>
---@field get_addons fun(): lib.list<lib.module.addon>
---@field initialize_all fun(): nil

---@class lib.module.addon
---@field id string
---@field dependencies (string|lib.module.addon)[]
---@field tags string[]
---@field to_dependency table<lib.module.addon, boolean>
---@field priority lib.reactive.ref
---@field is_enabled lib.reactive.ref
---@field is_visible lib.reactive.ref
---@field description lib.reactive.ref
---@field category lib.reactive.ref
---@field is_unlocked lib.reactive.ref
---@field has_initialized lib.reactive.ref
---@field is_active lib.reactive.computed
---@field on_activate any
---@field once_deactivate any
---@field on_initialize any
---@field on_deactivate any
---@field initialize fun(): nil
---@field bind_activation fun(func: fun(): lib.reactive.once_event|fun(): nil): nil
---@field create_frame_update_computed fun(expr: fun(): ...): lib.reactive.computed
---@type lib.module.addon.registry
local M

local PRIORITY = {
    MODELS = -100,
    NORMAL = 0,
}

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
local function normalize(args)
    args.id = args.id or args.name
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
    args.priority = args.priority or PRIORITY.NORMAL
end

---@param args lib.module.addon.options
local function validate(args)
    assert(type(args.name) == "string" and args.name ~= "", "addon name must be a non-empty string")
    assert(type(args.id) == "string" and args.id ~= "", "addon id must be a non-empty string")
end

---@param args lib.module.addon.options
---@param context lib.module.base.context
---@return lib.module.addon
local function create(args, context)
    ---@type lib.module.addon
    local addon = reactive.factory(args)
    addon.factory.set_class("addon")
    addon.id = args.id

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
            if not context.resolve_dependency(addon, dependency).is_active() then
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

    return addon
end

M = base.new({
    type_name = "addon",
    normalize = normalize,
    validate = validate,
    create = create,
    after_register = function(addon)
        metatablex.lock_new_fields(addon.dependencies)
        metatablex.lock_new_fields(addon.tags)
        metatablex.lock_new_fields(addon.to_dependency)
    end,
})

M.PRIORITY = PRIORITY

---@return lib.list<lib.module.addon>
function M.get_addons()
    return list(M.get_items())
end

function M.initialize_all()
    M.for_each(function(addon)
        addon.initialize()
    end)
end

return M
