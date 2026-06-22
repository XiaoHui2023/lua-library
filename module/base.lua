---@type lib.metatablex
local metatablex = require "lib.metatablex"
local module_path = (...):match("^(.*)%.[^.]+$") or "module"
---@type lib.module.order
local order = require(module_path .. ".order")

---@class lib.module.base.options
---@field type_name string
---@field create? fun(args: table, context: lib.module.base.context): table
---@field validate? fun(args: table): nil
---@field normalize? fun(args: table): nil
---@field after_register? fun(item: table, args: table, context: lib.module.base.context): nil

---@class lib.module.base.context
---@field type_name string
---@field resolve_dependency fun(owner: table, dependency: any): table
---@field lock_list fun(list: table): table

---@class lib.module.base
local M = {}

---@class lib.module.base.registry
---@operator call(table): table
---@field get_items fun(): table[]
---@field get fun(id: string): table?
---@field for_each fun(func: fun(item: table): nil): nil
---@field register fun(args: table): table

---@param type_name string
---@param item table
---@return string
local function item_id(type_name, item)
    local id = item and item.id
    if type(id) == "function" then
        id = id()
    end
    assert(type(id) == "string" and id ~= "", type_name .. " id must be a non-empty string")
    return id
end

---@param args lib.module.base.options
---@return lib.module.base.registry
function M.new(args)
    assert(type(args) == "table", "module.base.new requires options")
    assert(type(args.type_name) == "string" and args.type_name ~= "", "module type_name must be a non-empty string")

    local type_name = args.type_name
    local items = {}
    local id_to_item = {}
    local next_order_id = 1

    local function resolve_dependency(owner, dependency)
        if type(dependency) == "string" then
            local resolved = id_to_item[dependency]
            assert(resolved ~= nil, type_name .. "<" .. item_id(type_name, owner) .. "> dependency not registered: " .. dependency)
            return resolved
        end
        assert(type(dependency) == "table" and dependency.__module_kind == type_name, type_name .. "<" .. item_id(type_name, owner) .. "> dependency must be a " .. type_name .. " or id")
        return dependency
    end

    local context = {
        type_name = type_name,
        resolve_dependency = resolve_dependency,
        lock_list = metatablex.lock_new_fields,
    }

    ---@type lib.module.base.registry
    local registry = {}

    function registry.get_items()
        return order.sort(items, {
            type_name = type_name,
            dependencies = function(item)
                return item.dependencies
            end,
            resolve = resolve_dependency,
        })
    end

    function registry.get(id)
        return id_to_item[id]
    end

    function registry.for_each(func)
        for _, item in ipairs(registry.get_items()) do
            func(item)
        end
    end

    function registry.register(register_args)
        assert(type(register_args) == "table", type_name .. ".register requires options")
        if args.normalize ~= nil then
            args.normalize(register_args)
        end
        if args.validate ~= nil then
            args.validate(register_args)
        end
        local register_id = register_args.id
        if type(register_id) == "function" then
            register_id = register_id()
        end
        if register_id ~= nil then
            assert(id_to_item[register_id] == nil, "duplicate " .. type_name .. " id: " .. register_id)
        end

        local item
        if args.create ~= nil then
            item = args.create(register_args, context)
        else
            item = {}
        end
        assert(type(item) == "table", type_name .. ".create must return table")

        item.__module_kind = type_name
        item.dependencies = item.dependencies or register_args.dependencies or {}
        item.priority = item.priority or register_args.priority or 0
        item.order_id = next_order_id
        next_order_id = next_order_id + 1

        local id = item_id(type_name, item)
        if register_id ~= nil then
            assert(id == register_id, type_name .. ".create must keep id unchanged")
        end
        assert(id_to_item[id] == nil, "duplicate " .. type_name .. " id: " .. id)

        if args.after_register ~= nil then
            args.after_register(item, register_args, context)
        end

        items[#items + 1] = item
        id_to_item[id] = item

        return item
    end

    metatablex.callable(registry, registry.register)

    return registry
end

return M
