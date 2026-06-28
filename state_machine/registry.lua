---@class lib.state_machine.registry
local Registry = {}
Registry.__index = Registry

---@param args? { name?: string }
---@return lib.state_machine.registry
local function create_registry(args)
    args = args or {}
    return setmetatable({
        name = args.name or "state_machine_registry",
        _generators = {},
    }, Registry)
end

---@param key string
---@param generator fun(options:lib.state_machine.state.options):lib.state_machine.state
---@return lib.state_machine.registry
function Registry:register(key, generator)
    assert(type(key) == "string" and key ~= "", "state template key must be non-empty string")
    assert(type(generator) == "function", "state template generator must be function")
    self._generators[key] = generator
    return self
end

---@param key string
---@return boolean
function Registry:has(key)
    return self._generators[key] ~= nil
end

---@param key string
---@return fun(options:lib.state_machine.state.options):lib.state_machine.state
function Registry:get(key)
    local generator = self._generators[key]
    if generator == nil then
        error("state template not found: " .. tostring(key), 2)
    end
    return generator
end

---@param key string
---@return fun(options:lib.state_machine.state.options):lib.state_machine.state?
function Registry:find(key)
    return self._generators[key]
end

function Registry:clear()
    self._generators = {}
end

return create_registry
