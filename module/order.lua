---@class lib.module.order
local M = {}

---@param item any
---@return string
local function item_name(item)
    if item == nil then
        return "nil"
    end
    if type(item.id) == "function" then
        return tostring(item.id())
    end
    if item.id ~= nil then
        return tostring(item.id)
    end
    if type(item.name) == "function" then
        return tostring(item.name())
    end
    if item.name ~= nil then
        return tostring(item.name)
    end
    return tostring(item)
end

---@param path any[]
---@param repeated any
---@return string
local function format_cycle(path, repeated)
    local parts = {}
    local should_collect = false
    for _, item in ipairs(path) do
        if item == repeated then
            should_collect = true
        end
        if should_collect then
            parts[#parts + 1] = item_name(item)
        end
    end
    parts[#parts + 1] = item_name(repeated)
    return table.concat(parts, " -> ")
end

---@param item any
---@return integer
local function item_priority(item)
    if type(item.priority) == "function" or type(item.priority) == "table" then
        local ok, value = pcall(item.priority)
        if ok then
            return value
        end
    end
    return item.priority or 0
end

---@param value any
---@return any
local function unwrap_value(value)
    if type(value) == "function" or type(value) == "table" then
        local ok, result = pcall(value)
        if ok then
            return result
        end
    end
    return value
end

---@param a any
---@param b any
---@return boolean
local function item_less(a, b)
    local a_priority = item_priority(a)
    local b_priority = item_priority(b)
    if a_priority ~= b_priority then
        return a_priority < b_priority
    end
    local a_order = a.order_id or a.id or item_name(a)
    local b_order = b.order_id or b.id or item_name(b)
    a_order = unwrap_value(a_order)
    b_order = unwrap_value(b_order)
    if type(a_order) == "number" and type(b_order) == "number" then
        return a_order < b_order
    end
    return tostring(a_order) < tostring(b_order)
end

---@param items any[]
local function sort_items(items)
    table.sort(items, item_less)
end

---@class lib.module.order.options
---@field dependencies fun(item: any): any[]
---@field resolve fun(owner: any, dependency: any): any
---@field type_name? string

---@param items any[]
---@param options lib.module.order.options
---@return any[]
function M.sort(items, options)
    local roots = {}
    for _, item in ipairs(items) do
        roots[#roots + 1] = item
    end
    sort_items(roots)

    local ordered = {}
    local visited = {}
    local visiting = {}
    local path = {}

    local function visit(item)
        if visited[item] then
            return
        end
        if visiting[item] then
            error((options.type_name or "module") .. " dependency cycle: " .. format_cycle(path, item))
        end

        visiting[item] = true
        path[#path + 1] = item

        local dependencies = {}
        for _, dependency in ipairs(options.dependencies(item)) do
            dependencies[#dependencies + 1] = options.resolve(item, dependency)
        end
        sort_items(dependencies)
        for _, dependency in ipairs(dependencies) do
            visit(dependency)
        end

        path[#path] = nil
        visiting[item] = nil
        visited[item] = true
        ordered[#ordered + 1] = item
    end

    for _, item in ipairs(roots) do
        visit(item)
    end

    return ordered
end

return M
