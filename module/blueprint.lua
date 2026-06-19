---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.module.order
local module_path = (...):match("^(.*)%.[^.]+$") or "module"
local order = require(module_path .. ".order")

---@class lib.module.blueprint
---@operator call(...): lib.module.blueprint
local M = {}

---@type lib.module.blueprint[]
local BLUEPRINTS = {}

---@type table<string, lib.module.blueprint>
local ID_TO_BLUEPRINT = {}

local next_order_id = 1

---@param blueprint lib.module.blueprint
---@param dependency any
---@return lib.module.blueprint
local function resolve_dependency(blueprint, dependency)
    if type(dependency) == "string" then
        local resolved = ID_TO_BLUEPRINT[dependency]
        assert(resolved ~= nil, "blueprint<" .. blueprint.id .. "> dependency not registered: " .. dependency)
        return resolved
    end
    assert(type(dependency) == "table" and dependency.__module_kind == "blueprint", "blueprint<" .. blueprint.id .. "> dependency must be a blueprint or id")
    return dependency
end

---@return lib.module.blueprint[]
function M.get_blueprints()
    return order.sort(BLUEPRINTS, {
        type_name = "blueprint",
        dependencies = function(blueprint)
            return blueprint.dependencies
        end,
        resolve = resolve_dependency,
    })
end

---@param id string
---@return lib.module.blueprint?
function M.get(id)
    return ID_TO_BLUEPRINT[id]
end

---@param func fun(blueprint: lib.module.blueprint): nil
function M.for_each(func)
    for _, blueprint in ipairs(M.get_blueprints()) do
        func(blueprint)
    end
end

---@param id string
---@return any
function M.load(id)
    local blueprint = assert(M.get(id), "blueprint not registered: " .. tostring(id))
    return blueprint.load()
end

---@class lib.module.blueprint.options
---@field id string
---@field name string
---@field description? string
---@field dependencies? (string|lib.module.blueprint)[]
---@field tags? string[]
---@field category? string
---@field loader? fun(): any
---@field module? string
---@field priority? integer

---@param args lib.module.blueprint.options
---@return lib.module.blueprint
function M.register(args)
    assert(type(args) == "table", "blueprint.register requires options")
    assert(type(args.id) == "string" and args.id ~= "", "blueprint id must be a non-empty string")
    assert(type(args.name) == "string" and args.name ~= "", "blueprint name must be a non-empty string")
    assert(ID_TO_BLUEPRINT[args.id] == nil, "duplicate blueprint id: " .. args.id)
    assert(args.loader == nil or type(args.loader) == "function", "blueprint loader must be a function")
    assert(args.module == nil or type(args.module) == "string", "blueprint module must be a string")

    ---@class lib.module.blueprint
    local blueprint = {
        __module_kind = "blueprint",
        id = args.id,
        name = args.name,
        description = args.description or "",
        dependencies = args.dependencies or {},
        tags = args.tags or {},
        category = args.category or "",
        priority = args.priority or 0,
        has_loaded = false,
        value = nil,
        order_id = next_order_id,
    }
    next_order_id = next_order_id + 1

    local loader = args.loader
    if loader == nil and args.module ~= nil then
        loader = function()
            return require(args.module)
        end
    end

    function blueprint.load()
        if blueprint.has_loaded then
            return blueprint.value
        end
        for _, dependency in ipairs(blueprint.dependencies) do
            resolve_dependency(blueprint, dependency).load()
        end
        if loader ~= nil then
            blueprint.value = loader()
        end
        blueprint.has_loaded = true
        return blueprint.value
    end

    metatablex.lock_new_fields(blueprint.dependencies)
    metatablex.lock_new_fields(blueprint.tags)

    BLUEPRINTS[#BLUEPRINTS + 1] = blueprint
    ID_TO_BLUEPRINT[blueprint.id] = blueprint

    return blueprint
end

metatablex.callable(M, M.register)

return M
