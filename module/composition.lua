local module_path = (...):match("^(.*)%.[^.]+$") or "module"
---@type lib.module.base
local base = require(module_path .. ".base")

---@class lib.module.composition.registry: lib.module.base.registry
---@operator call(lib.module.composition.options): lib.module.composition
---@field PRIORITY table<string, integer>
---@field get_compositions fun(): lib.module.composition[]
---@field compose_all fun(): nil

---@class lib.module.composition
---@field id string
---@field dependencies (string|lib.module.composition)[]
---@field priority integer
---@field has_composed boolean
---@field on_compose fun(func: fun(): nil): nil
---@field compose fun(): nil
---@type lib.module.composition.registry
local M

local PRIORITY = {
    PROFILE = -200,
    SCENE = -100,
    NORMAL = 0,
}

---@class lib.module.composition.options
---@field id string
---@field dependencies? (string|lib.module.composition)[]
---@field priority? integer
---@field compose? fun(): nil

---@param args lib.module.composition.options
local function normalize(args)
    args.dependencies = args.dependencies or {}
    args.priority = args.priority or PRIORITY.NORMAL
end

---@param args lib.module.composition.options
local function validate(args)
    assert(type(args.id) == "string" and args.id ~= "", "composition id must be a non-empty string")
end

---@param args lib.module.composition.options
---@return lib.module.composition
local function create(args)
    ---@type lib.module.composition
    local composition = {
        id = args.id,
        dependencies = args.dependencies,
        priority = args.priority,
        has_composed = false,
    }

    local compose_handlers = {}

    function composition.on_compose(func)
        assert(type(func) == "function", "composition.on_compose requires function")
        compose_handlers[#compose_handlers + 1] = func
    end

    if args.compose ~= nil then
        composition.on_compose(args.compose)
    end

    function composition.compose()
        if composition.has_composed then
            return
        end
        for _, func in ipairs(compose_handlers) do
            func()
        end
        composition.has_composed = true
    end

    return composition
end

M = base.new({
    type_name = "composition",
    normalize = normalize,
    validate = validate,
    create = create,
    after_register = function(composition, _, context)
        context.lock_list(composition.dependencies)
    end,
})

M.PRIORITY = PRIORITY

---@return lib.module.composition[]
function M.get_compositions()
    return M.get_items()
end

function M.compose_all()
    M.for_each(function(composition)
        composition.compose()
    end)
end

return M
