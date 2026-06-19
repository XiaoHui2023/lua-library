---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.module.order
local module_path = (...):match("^(.*)%.[^.]+$") or "module"
local order = require(module_path .. ".order")

---@class lib.module.system
---@operator call(...): lib.module.system
local M = {}

M.PRIORITY = {
    FRAMEWORK = -200,
    GAME = -100,
    NORMAL = 0,
}

---@type lib.module.system[]
local SYSTEMS = {}

---@type table<string, lib.module.system>
local ID_TO_SYSTEM = {}

local next_order_id = 1

---@param system lib.module.system
---@param dependency any
---@return lib.module.system
local function resolve_dependency(system, dependency)
    if type(dependency) == "string" then
        local resolved = ID_TO_SYSTEM[dependency]
        assert(resolved ~= nil, "system<" .. system.id .. "> dependency not registered: " .. dependency)
        return resolved
    end
    assert(type(dependency) == "table" and dependency.__module_kind == "system", "system<" .. system.id .. "> dependency must be a system or id")
    return dependency
end

---@return lib.module.system[]
function M.get_systems()
    return order.sort(SYSTEMS, {
        type_name = "system",
        dependencies = function(system)
            return system.dependencies
        end,
        resolve = resolve_dependency,
    })
end

---@param func fun(system: lib.module.system): nil
function M.for_each(func)
    for _, system in ipairs(M.get_systems()) do
        func(system)
    end
end

function M.initialize_all()
    M.for_each(function(system)
        system.initialize()
    end)
end

---@class lib.module.system.options
---@field id string
---@field dependencies? (string|lib.module.system)[]
---@field priority? integer
---@field init? fun(): nil

---@param args lib.module.system.options
---@return lib.module.system
function M.register(args)
    assert(type(args) == "table", "system.register requires options")
    assert(type(args.id) == "string" and args.id ~= "", "system id must be a non-empty string")
    assert(ID_TO_SYSTEM[args.id] == nil, "duplicate system id: " .. args.id)

    ---@class lib.module.system
    local system = {
        __module_kind = "system",
        id = args.id,
        dependencies = args.dependencies or {},
        priority = args.priority or M.PRIORITY.NORMAL,
        has_initialized = false,
        order_id = next_order_id,
    }
    next_order_id = next_order_id + 1

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

    metatablex.lock_new_fields(system.dependencies)

    SYSTEMS[#SYSTEMS + 1] = system
    ID_TO_SYSTEM[system.id] = system

    return system
end

metatablex.callable(M, M.register)

return M
