local module_path = (...):match("^(.*)%.[^.]+$") or "module"
---@type lib.module.base
local base = require(module_path .. ".base")

---@class lib.module.blueprint.registry: lib.module.base.registry
---@operator call(lib.module.blueprint.options): lib.module.blueprint
---@field get_blueprints fun(): lib.module.blueprint[]
---@field load fun(id: string): any

---@class lib.module.blueprint
---@field id string
---@field name string
---@field description string
---@field dependencies (string|lib.module.blueprint)[]
---@field tags string[]
---@field category string
---@field priority integer
---@field has_loaded boolean
---@field value any
---@field load fun(): any
---@type lib.module.blueprint.registry
local M

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
local function normalize(args)
    args.description = args.description or ""
    args.dependencies = args.dependencies or {}
    args.tags = args.tags or {}
    args.category = args.category or ""
    args.priority = args.priority or 0
end

---@param args lib.module.blueprint.options
local function validate(args)
    assert(type(args.id) == "string" and args.id ~= "", "blueprint id must be a non-empty string")
    assert(type(args.name) == "string" and args.name ~= "", "blueprint name must be a non-empty string")
    assert(args.loader == nil or type(args.loader) == "function", "blueprint loader must be a function")
    assert(args.module == nil or type(args.module) == "string", "blueprint module must be a string")
end

---@param args lib.module.blueprint.options
---@param context lib.module.base.context
---@return lib.module.blueprint
local function create(args, context)
    ---@type lib.module.blueprint
    local blueprint = {
        id = args.id,
        name = args.name,
        description = args.description,
        dependencies = args.dependencies,
        tags = args.tags,
        category = args.category,
        priority = args.priority,
        has_loaded = false,
        value = nil,
    }

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
            context.resolve_dependency(blueprint, dependency).load()
        end
        if loader ~= nil then
            blueprint.value = loader()
        end
        blueprint.has_loaded = true
        return blueprint.value
    end

    return blueprint
end

M = base.new({
    type_name = "blueprint",
    normalize = normalize,
    validate = validate,
    create = create,
    after_register = function(blueprint, _, context)
        context.lock_list(blueprint.dependencies)
        context.lock_list(blueprint.tags)
    end,
})

---@return lib.module.blueprint[]
function M.get_blueprints()
    return M.get_items()
end

---@param id string
---@return any
function M.load(id)
    local blueprint = assert(M.get(id), "blueprint not registered: " .. tostring(id))
    return blueprint.load()
end

return M
