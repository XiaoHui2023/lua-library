---@type lib.tablex
local tablex = require "lib.tablex"

local M = {}

local function noop()
end

---@param value any
---@return boolean
local function is_disposable(value)
    return type(value) == "table"
        and (value.on_dispose ~= nil
            or (value.factory ~= nil and value.factory.delete ~= nil)
            or value.delete ~= nil
            or value.dispose ~= nil
            or value.clear ~= nil)
end

---@param owner any
---@param remove fun()
---@return fun()
function M.bind_owner_delete(owner, remove)
    if not is_disposable(owner) then
        return noop
    end
    if type(owner.on_dispose) == "table" and owner.on_dispose.add ~= nil then
        return owner.on_dispose.add(remove)
    end
    if type(owner.factory) == "table" and type(owner.factory.delete) == "table" and owner.factory.delete.add ~= nil then
        return owner.factory.delete.add(remove)
    end
    if type(owner.delete) == "table" and owner.delete.add ~= nil then
        return owner.delete.add(remove)
    end
    if type(owner.dispose) == "table" and owner.dispose.add ~= nil then
        return owner.dispose.add(remove)
    end
    if type(owner.clear) == "table" and owner.clear.add ~= nil then
        return owner.clear.add(remove)
    end
    return noop
end

---@param modifier lib.damage.modifier
---@return lib.damage.modifier
function M.normalize(modifier)
    assert(type(modifier) == "table", "modifier must be table")
    assert(type(modifier.callback) == "function", "modifier.callback must be function")

    local normalized = tablex.clone(modifier)
    normalized.priority = normalized.priority or 0
    normalized.enabled = normalized.enabled ~= false
    normalized.owner = normalized.owner or normalized.source
    normalized.name = normalized.name or ""
    if normalized.uses ~= nil then
        assert(type(normalized.uses) == "number", "modifier.uses must be number")
        assert(normalized.uses >= 0, "modifier.uses must be >= 0")
    end
    return normalized
end

---@param value any
---@param mode lib.damage.modifier_mode
function M.assert_value(value, mode)
    if value == nil then
        return
    end
    if mode == "or" or mode == "and" then
        assert(type(value) == "boolean", "modifier return value must be boolean")
    elseif mode == "min" or mode == "max" then
        assert(type(value) == "number", "modifier return value must be number")
    end
end

---@param old_value any
---@param new_value any
---@param mode lib.damage.modifier_mode
---@return boolean
function M.should_apply_value(old_value, new_value, mode)
    if old_value == nil then
        return true
    end
    if mode == "min" then
        return new_value < old_value
    end
    if mode == "max" then
        return new_value > old_value
    end
    return true
end

---@param mode lib.damage.modifier_mode
---@param initial any
---@return any
function M.default_value(mode, initial)
    if mode == "and" then
        return true
    end
    if mode == "or" then
        return false
    end
    return initial
end

---@param mode lib.damage.modifier_mode
---@param value any
---@return boolean
function M.should_stop(mode, value)
    if mode == "first" then
        return true
    end
    if mode == "or" then
        return value == true
    end
    if mode == "and" then
        return value == false
    end
    return false
end

---@param modifier lib.damage.modifier
---@return boolean
function M.can_use(modifier)
    return modifier.enabled ~= false and (modifier.uses == nil or modifier.uses > 0)
end

return M
