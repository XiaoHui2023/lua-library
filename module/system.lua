local module_path = (...):match("^(.*)%.[^.]+$") or "module"
---@type lib.module.base
local base = require(module_path .. ".base")

---@class lib.module.system.registry: lib.module.base.registry
---@operator call(lib.module.system.options): lib.module.system
---@field PRIORITY table<string, integer>

---@class lib.module.system
---@field id string
---@field dependencies (string|lib.module.system)[]
---@field priority integer
---@field has_initialized boolean
---@field on_initialize fun(func: fun(): nil): nil
---@field initialize fun(): nil
---@type lib.module.system.registry
local M

local PRIORITY = {
    FRAMEWORK = -200,
    GAME = -100,
    NORMAL = 0,
}

---@class lib.module.system.options
---@field id string
---@field dependencies? (string|lib.module.system)[]
---@field priority? integer
---@field init? fun(): nil

---@param args lib.module.system.options
local function normalize(args)
    args.dependencies = args.dependencies or {}
    args.priority = args.priority or PRIORITY.NORMAL
end

---@param args lib.module.system.options
local function validate(args)
    assert(type(args.id) == "string" and args.id ~= "", "system id must be a non-empty string")
end

---@param args lib.module.system.options
---@return lib.module.system
local function create(args)
    ---@type lib.module.system
    local system = {
        id = args.id,
        dependencies = args.dependencies,
        priority = args.priority,
        has_initialized = false,
    }

    local initialize_handlers = {}

    function system.on_initialize(func)
        assert(type(func) == "function", "system.on_initialize requires function")
        initialize_handlers[#initialize_handlers + 1] = func
    end

    if args.init ~= nil then
        system.on_initialize(args.init)
    end

    function system.initialize()
        if system.has_initialized then
            return
        end
        for _, func in ipairs(initialize_handlers) do
            func()
        end
        system.has_initialized = true
    end

    return system
end

M = base.new({
    type_name = "system",
    normalize = normalize,
    validate = validate,
    create = create,
    after_register = function(system, _, context)
        context.lock_list(system.dependencies)
    end,
})

M.PRIORITY = PRIORITY

---@return lib.module.system[]
function M.get_systems()
    return M.get_items()
end

function M.initialize_all()
    M.for_each(function(system)
        system.initialize()
    end)
end

return M
