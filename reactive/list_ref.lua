---列表 list-ref-model

local reactive_base = require "reactive.base"
local event = require "reactive.event"
local track = require "reactive.track"

local M = {}

---@param items table
---@param value any
---@param equals fun(a:any,b:any):boolean
---@return integer|nil
local function index_of(items, value, equals)
    for index = 1, #items do
        if equals(items[index], value) then
            return index
        end
    end
    return nil
end

---@param args? table 列表引用配置
---@return table
function M.new(args)
    args = args or {}
    local items = {}
    if args.value ~= nil then
        for index = 1, #args.value do
            items[index] = args.value[index]
        end
    end
    local item_checker = args.item_checker
    local prevent_duplicate = args.prevent_duplicate or false
    local compare = args.compare
    local equals = args.equals or function(a, b)
        return a == b
    end

    local base = reactive_base.new({ name = args.name or "" })
    local on_change = event.new({ name = (args.name or "") .. ".change" })
    local on_set = event.new({ name = (args.name or "") .. ".set" })
    local on_dispose = event.new({ mode = "once", name = (args.name or "") .. ".dispose" })

    local o = {
        type = "list_ref",
        on_change = on_change.as_listener(),
        on_set = on_set.as_listener(),
        on_dispose = on_dispose.as_listener(),
    }

    local function copy_items()
        local result = {}
        for index = 1, #items do
            result[index] = items[index]
        end
        return result
    end

    local function check_item(value)
        if item_checker and not item_checker(value) then
            error(string.format("list_ref<%s> item check failed: %s", o.get_name(), tostring(value)))
        end
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

    function o.count()
        o.track()
        return #items
    end

    function o.get(index)
        o.track()
        return items[index]
    end

    function o.set(index, value)
        if base.is_disposed() then
            return
        end
        check_item(value)
        local old_value = items[index]
        items[index] = value
        on_set.run(index, value, old_value)
        if not equals(value, old_value) then
            touch_change("set", index, value, old_value)
        end
    end

    function o.append(value)
        if base.is_disposed() then
            return function() end
        end
        check_item(value)
        if prevent_duplicate and index_of(items, value, equals) ~= nil then
            return function() end
        end
        table.insert(items, value)
        touch_change("append", value)
        local removed = false
        return function()
            if removed then
                return
            end
            removed = true
            o.remove(value)
        end
    end

    function o.remove(value)
        if base.is_disposed() then
            return false
        end
        local index = index_of(items, value, equals)
        if index == nil then
            return false
        end
        table.remove(items, index)
        touch_change("remove", value, index)
        return true
    end

    function o.remove_at(index)
        if base.is_disposed() then
            return false
        end
        local value = items[index]
        if value == nil then
            return false
        end
        table.remove(items, index)
        touch_change("remove_at", value, index)
        return true
    end

    function o.clear()
        if base.is_disposed() then
            return
        end
        if #items == 0 then
            return
        end
        items = {}
        touch_change("clear")
    end

    function o.sort()
        if base.is_disposed() then
            return
        end
        if compare == nil then
            error(string.format("list_ref<%s> sort requires compare", o.get_name()))
        end
        table.sort(items, compare)
        touch_change("sort")
    end

    function o.iter()
        o.track()
        local index = 0
        return function()
            index = index + 1
            return items[index]
        end
    end

    function o.raw_get()
        return items
    end

    function o.get_all()
        o.track()
        return copy_items()
    end

    function o.dispose()
        if base.is_disposed() then
            return
        end
        on_dispose.run()
        on_change.clear()
        on_set.clear()
        on_dispose.clear()
        items = {}
        base.mark_disposed()
    end

    setmetatable(o, {
        __call = function()
            return o.get_all()
        end,
    })

    return o
end

return M
