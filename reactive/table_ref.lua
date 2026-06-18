---字典 table-ref-model

local reactive_base = require "reactive.base"
local event = require "reactive.event"
local track = require "reactive.track"

local M = {}

---@param args? table 字典引用配置
---@return table
function M.new(args)
    args = args or {}
    local data = {}
    if args.value ~= nil then
        for key, value in pairs(args.value) do
            data[key] = value
        end
    end
    local key_checker = args.key_checker
    local value_checker = args.value_checker
    local equals = args.equals or function(a, b)
        return a == b
    end

    local base = reactive_base.new({ name = args.name or "" })
    local on_change = event.new({ name = (args.name or "") .. ".change" })
    local on_set = event.new({ name = (args.name or "") .. ".set" })
    local on_dispose = event.new({ mode = "once", name = (args.name or "") .. ".dispose" })

    local o = {
        type = "table_ref",
        on_change = on_change.as_listener(),
        on_set = on_set.as_listener(),
        on_dispose = on_dispose.as_listener(),
    }

    local function copy_data()
        local result = {}
        for key, value in pairs(data) do
            result[key] = value
        end
        return result
    end

    local function check_key(key)
        if key_checker and not key_checker(key) then
            error(string.format("table_ref<%s> key check failed: %s", o.get_name(), tostring(key)))
        end
    end

    local function check_value(value)
        if value_checker and not value_checker(value) then
            error(string.format("table_ref<%s> value check failed: %s", o.get_name(), tostring(value)))
        end
    end

    local function make_key(...)
        local count = select("#", ...)
        if count == 1 then
            return ...
        end
        local parts = {}
        for index = 1, count do
            local value = select(index, ...)
            parts[index] = type(value) .. ":" .. tostring(value)
        end
        return table.concat(parts, "\31")
    end

    local function touch_change(...)
        base.touch()
        on_change.run(...)
    end

    function o.get_name()
        return base.get_name()
    end

    function o.set_name(name)
        base.set_name(name)
    end

    function o.get_version()
        return base.get_version()
    end

    function o.is_disposed()
        return base.is_disposed()
    end

    function o.track()
        if base.is_disposed() then
            return
        end
        track.register(o)
    end

    function o.get(...)
        o.track()
        local key = make_key(...)
        return data[key]
    end

    function o.get_or(key, fallback)
        o.track()
        local value = data[key]
        if value == nil then
            return fallback
        end
        return value
    end

    function o.set(...)
        if base.is_disposed() then
            return function() end
        end
        local count = select("#", ...)
        assert(count >= 2, "table_ref set requires key and value")
        local value = select(count, ...)
        local key = make_key(table.unpack({ ... }, 1, count - 1))
        check_key(key)
        check_value(value)
        local old_value = data[key]
        data[key] = value
        on_set.run(key, value, old_value)
        if not equals(value, old_value) then
            touch_change("set", key, value, old_value)
        end
        local removed = false
        return function()
            if removed then
                return
            end
            removed = true
            if data[key] == value then
                o.remove(key)
            end
        end
    end

    function o.bind(key, value)
        return o.set(key, value)
    end

    function o.remove(key)
        if base.is_disposed() then
            return
        end
        if data[key] == nil then
            return
        end
        local old_value = data[key]
        data[key] = nil
        touch_change("remove", key, old_value)
    end

    function o.has(key)
        o.track()
        return data[key] ~= nil
    end

    function o.clear()
        if base.is_disposed() then
            return
        end
        if next(data) == nil then
            return
        end
        data = {}
        touch_change("clear")
    end

    function o.iter()
        o.track()
        return pairs(data)
    end

    function o.keys()
        o.track()
        local result = {}
        for key in pairs(data) do
            table.insert(result, key)
        end
        return result
    end

    function o.values()
        o.track()
        local result = {}
        for _, value in pairs(data) do
            table.insert(result, value)
        end
        return result
    end

    function o.raw_get()
        return data
    end

    function o.get_all()
        o.track()
        return copy_data()
    end

    function o.dispose()
        if base.is_disposed() then
            return
        end
        on_dispose.run()
        on_change.clear()
        on_set.clear()
        on_dispose.clear()
        data = {}
        base.mark_disposed()
    end

    setmetatable(o, {
        __call = function(_, key)
            return o.get(key)
        end,
    })

    return o
end

return M
