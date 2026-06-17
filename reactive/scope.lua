local event = require "reactive.event"

local M = {}

local function dispose_item(item)
    if item == nil then
        return
    end
    if type(item) == "function" then
        item()
        return
    end
    if type(item) ~= "table" then
        return
    end
    if item.dispose ~= nil then
        item.dispose()
    elseif item.delete ~= nil then
        item.delete()
    elseif item.clear ~= nil then
        item.clear()
    end
end

---@param args? { name?: string }
---@return table
function M.new(args)
    args = args or {}
    local disposed = false
    local items = {}
    local on_dispose = event.once({ name = (args.name or "") .. ".dispose" })

    local o = {
        type = "scope",
        on_dispose = on_dispose.as_listener(),
    }

    function o.add(item)
        if disposed then
            dispose_item(item)
            return function() end
        end
        local removed = false
        table.insert(items, item)
        return function()
            if removed then
                return
            end
            removed = true
            for index = #items, 1, -1 do
                if items[index] == item then
                    table.remove(items, index)
                    return
                end
            end
        end
    end

    function o.mount(item)
        return o.add(item)
    end

    function o.attach(item)
        return o.add(item)
    end

    function o.dispose()
        if disposed then
            return
        end
        disposed = true
        for index = #items, 1, -1 do
            dispose_item(items[index])
        end
        items = {}
        on_dispose.run()
        on_dispose.clear()
    end

    function o.is_disposed()
        return disposed
    end

    function o.clear()
        o.dispose()
    end

    setmetatable(o, {
        __call = function()
            o.dispose()
        end,
    })

    return o
end

return M
