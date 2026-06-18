local reactive_base = require "reactive.base"
local event = require "reactive.event"
local track = require "reactive.track"
local list = require "list"

local M = {}

---@class lib.reactive.collection<T>
---@field type "collection" 集合类型标记
---@field on_add table 添加监听器
---@field on_get table 读取监听器
---@field on_change table 变化监听器
---@field get fun():list 读取集合列表
---@field add fun(item:any):function 添加元素并返回删除函数
---@field clear fun() 清空集合
---@field any fun():boolean 是否存在元素
---@field empty fun():boolean 是否为空
---@field count fun():integer 元素数量
---@field dispose fun() 销毁集合

---@param args? table 集合配置
---@return lib.reactive.collection
function M.new(args)
    args = args or {}
    local items = list()
    local compare = args.compare
    local prevent_duplicate = args.prevent_duplicate or false
    local item_checker = args.item_checker or args.type_checker
    local normalize = args.normalize
    local reversed = args.reversed or false

    local base = reactive_base.new({ name = args.name or "" })
    local on_add = event.new({ name = (args.name or "") .. ".add" })
    local on_get = event.new({ name = (args.name or "") .. ".get" })
    local on_change = event.new({ name = (args.name or "") .. ".change" })
    local on_dispose = event.once({ name = (args.name or "") .. ".dispose" })

    local o = {
        type = "collection",
        on_add = on_add.as_listener(),
        on_get = on_get.as_listener(),
        on_change = on_change.as_listener(),
        on_dispose = on_dispose.as_listener(),
    }

    local function sort_items()
        items = items.sort(compare, reversed)
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

    function o.get()
        o.track()
        on_get.run(items)
        return items
    end

    function o.add(item)
        if base.is_disposed() then
            return function() end
        end
        if normalize ~= nil then
            item = normalize(item)
        end
        if item_checker and not item_checker(item) then
            error(string.format("collection<%s> item check failed: %s", o.get_name(), tostring(item)))
        end
        if prevent_duplicate and items.contains(item) then
            return function() end
        end

        local remove_from_list = items.append(item)
        sort_items()
        base.touch()
        on_change.run("add", item)

        local removed = false
        local remove = function()
            if removed then
                return
            end
            removed = true
            remove_from_list()
            base.touch()
            on_change.run("remove", item)
        end
        on_add.run(item, remove)
        return remove
    end

    function o.normalize(func)
        assert(type(func) == "function", "collection normalize must be a function")
        normalize = func
        return o
    end

    function o.wrap_add(func)
        return o.normalize(func)
    end

    function o.clear()
        if base.is_disposed() then
            return
        end
        items.clear()
        base.touch()
        on_change.run("clear")
    end

    function o.any()
        o.track()
        return items.any()
    end

    function o.empty()
        o.track()
        return items.empty()
    end

    function o.count()
        o.track()
        return items.count
    end

    function o.dispose()
        if base.is_disposed() then
            return
        end
        on_dispose.run()
        on_add.clear()
        on_get.clear()
        on_change.clear()
        on_dispose.clear()
        items.clear()
        base.mark_disposed()
    end

    setmetatable(o, {
        __call = function()
            return o.get()
        end,
        __index = function(_, key)
            if key == "count" then
                return o.count()
            end
            return nil
        end,
    })

    return o
end

return M
