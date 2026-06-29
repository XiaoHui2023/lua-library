---@type lib.stringx
local stringx = require "lib.stringx"
---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.tablex
local tablex = require "lib.tablex"

---@class lib.template
local M = {}

---@alias lib.template.value_reader fun(input:table, placeholder:string, context:table):(boolean, any)

local function read_callable(value)
    if type(value) == "function" then
        local ok, result = pcall(value)
        if ok then
            return result
        end
        return nil
    end

    local metatable = type(value) == "table" and getmetatable(value) or nil
    if metatable == nil or type(metatable.__call) ~= "function" then
        return value
    end
    local ok, result = pcall(value)
    if ok then
        return result
    end
    return nil
end

---@param data table|function|nil
---@param path string
---@return any
function M.get_path(data, path)
    local value = read_callable(data)
    for part in string.gmatch(path, "[^%.]+") do
        value = read_callable(value)
        if value == nil or type(value) ~= "table" then
            return nil
        end
        value = value[part]
    end
    return read_callable(value)
end

---@param value any
---@return string
function M.format_value(value)
    if value == nil then
        return ""
    end
    if type(value) == "number" then
        return tostring(math.floor(value + 0.5))
    end
    return tostring(value)
end

---@param args table
---@return table
function M.create_path_context(args)
    assert(type(args) == "table", "template path context args must be table")
    local input = args.input
    return {
        name = args.name,
        find = function(placeholder)
            local value = M.get_path(input, placeholder)
            if value == nil then
                return nil
            end
            return {
                value = value,
            }
        end,
        get_prop_fields = function()
            return {}
        end,
    }
end

---@param template_text string?
---@param data table|function|nil
---@return string
function M.render_text(template_text, data)
    template_text = template_text or ""
    template_text = string.gsub(template_text, "{{%s*([%w_%.]+)%s*}}", "{%1}")
    local renderer = M.create_template_renderer({
        exposed_contexts = {
            M.create_path_context({
                input = data,
            }),
        },
    })
    renderer.placeholder_renderers.add(M.create_placeholder_renderer({
        stage = "format",
        priority = -100,
        on_render = function(context)
            context.value = M.format_value(context.value)
        end,
    }))
    return renderer(template_text)
end

local VALID_STAGES = {
    format = true,
    locale = true,
    coloring = true,
    join = true,
}

---@param value any
---@param validator? fun(value:any):boolean 值校验函数；省略时不校验
---@param message? string 校验失败时使用的错误信息
---@return table
local function create_ref(value, validator, message)
    local ref = {}

    function ref.set(new_value)
        if validator ~= nil then
            assert(validator(new_value), message or "ref value is invalid")
        end
        value = new_value
    end

    return setmetatable(ref, {
        __call = function(_, new_value)
            if new_value ~= nil then
                ref.set(new_value)
            end
            return value
        end,
    })
end

---@generic T
---@param items T[]
---@param less fun(a:T,b:T):boolean
---@return T[]
local function stable_sort(items, less)
    local sorted = {}

    for _, item in ipairs(items) do
        local insert_at = #sorted + 1
        for index = 1, #sorted do
            if less(item, sorted[index]) then
                insert_at = index
                break
            end
        end
        table.insert(sorted, insert_at, item)
    end

    return sorted
end

---@param value any
---@return boolean
local function is_entry(value)
    return type(value) == "table" and (value.value ~= nil or value.values ~= nil)
end

---@param value any
---@return table
local function to_entry(value)
    if is_entry(value) then
        return tablex.clone(value)
    end
    return {
        value = value,
    }
end

---@type lib.template.value_reader
local default_value_reader = function(input, placeholder)
    local value = input[placeholder]
    if value == nil then
        return false, nil
    end
    return true, value
end

---@param reader lib.template.value_reader
function M.set_default_value_reader(reader)
    assert(type(reader) == "function", "template default value reader must be function")
    default_value_reader = reader
end

---@return lib.template.value_reader
function M.get_default_value_reader()
    return default_value_reader
end

---@class lib.template.table_context.options
---@field name? string|fun():string 上下文名称
---@field input table 输入数据表
---@field value_reader? lib.template.value_reader 输入数据读取函数

---@param args lib.template.table_context.options
---@return table
function M.create_table_context(args)
    assert(type(args) == "table", "template table context args must be table")
    assert(type(args.input) == "table", "template table context input must be table")
    assert(args.value_reader == nil or type(args.value_reader) == "function", "template table context value_reader must be function")

    local input = args.input
    local value_reader = args.value_reader

    return {
        name = args.name,
        find = function(placeholder)
            local reader = value_reader or default_value_reader
            local found, value = reader(input, placeholder, args)
            if found == nil or found ~= true and found ~= false then
                value = found
                found = value ~= nil
            end
            if not found then
                return nil
            end
            return to_entry(value)
        end,
        get_prop_fields = function()
            local fields = {}
            for key in pairs(input) do
                fields[#fields + 1] = key
            end
            table.sort(fields, function(a, b)
                return tostring(a) < tostring(b)
            end)
            return fields
        end,
    }
end

---@class lib.template.collection.options
---@field compare? fun(a:any,b:any):boolean 集合排序函数
---@field reversed? boolean 导出时是否反向排列

---@param args? lib.template.collection.options 集合配置
---@return table
local function create_collection(args)
    args = args or {}
    local entries = {}
    local compare = args.compare
    local reversed = args.reversed or false
    local collection = {}
    local next_id = 1

    local function sort_items()
        if compare == nil then
            return
        end
        entries = stable_sort(entries, function(a, b)
            return compare(a.value, b.value)
        end)
    end

    function collection.add(item)
        local id = next_id
        next_id = next_id + 1
        entries[#entries + 1] = {
            id = id,
            value = item,
        }
        sort_items()

        local removed = false
        return function()
            if removed then
                return
            end
            removed = true
            for index, entry in ipairs(entries) do
                if entry.id == id then
                    table.remove(entries, index)
                    return
                end
            end
        end
    end

    function collection.clear()
        entries = {}
    end

    function collection.to_table()
        local result = {}
        for index, entry in ipairs(entries) do
            result[index] = entry.value
        end
        if reversed then
            local reversed_result = {}
            for index = #result, 1, -1 do
                reversed_result[#reversed_result + 1] = result[index]
            end
            return reversed_result
        end
        return result
    end

    function collection.for_each(callback)
        assert(type(callback) == "function", "collection callback must be function")
        local should_stop = false
        local snapshot = collection.to_table()

        for index, item in ipairs(snapshot) do
            local context = {
                index = index,
                stop = function()
                    should_stop = true
                end,
            }
            callback(item, context)
            if should_stop then
                return
            end
        end
    end

    function collection.filter(predicate)
        assert(type(predicate) == "function", "collection predicate must be function")
        local filtered = create_collection()
        collection.for_each(function(item)
            if predicate(item) then
                filtered.add(item)
            end
        end)
        return filtered
    end

    function collection.count()
        return #entries
    end

    setmetatable(collection, {
        __call = function()
            return collection
        end,
        __index = function(_, key)
            if key == "count" then
                return #entries
            end
        end,
    })

    return collection
end

---@alias lib.template.placeholder_renderer_stage
---| "format"
---| "locale"
---| "coloring"
---| "join"

---@class lib.template.placeholder_renderer.options
---@field stage lib.template.placeholder_renderer_stage 占位符渲染阶段
---@field on_render fun(context:table) 占位符渲染函数
---@field priority? number 渲染器排序优先级，数值越小越靠前

---@param args lib.template.placeholder_renderer.options
---@return lib.template.placeholder_renderer
function M.create_placeholder_renderer(args)
    assert(type(args) == "table", "placeholder renderer args must be table")
    assert(VALID_STAGES[args.stage] == true, "placeholder renderer stage is invalid")
    assert(type(args.on_render) == "function", "placeholder renderer on_render must be function")
    assert(args.priority == nil or type(args.priority) == "number", "placeholder renderer priority must be number")

    ---@class lib.template.placeholder_renderer
    local renderer = {
        class_name = "lib.template.placeholder_renderer",
        stage = create_ref(args.stage, function(value)
            return VALID_STAGES[value] == true
        end, "placeholder renderer stage is invalid"),
        on_render = args.on_render,
        priority = create_ref(args.priority or 0, function(value)
            return type(value) == "number"
        end, "placeholder renderer priority must be number"),
    }

    function renderer.set_class(class_name)
        renderer.class_name = class_name
    end

    function renderer.is_instance_of(value, class_name)
        return type(value) == "table" and (value.class_name == class_name or value.type == class_name)
    end

    metatablex.with_metatable(renderer, {
        __tostring = function(self)
            return stringx.format("<%s stage=%s priority=%s>", self.class_name, self.stage(), self.priority())
        end,
    })

    return renderer
end

---@class lib.template.renderer.options
---@field exposed_contexts? table[] 可供占位符查找的外部上下文列表
---@field value_reader? lib.template.value_reader 输入 table 的读取函数

---@param args? lib.template.renderer.options 模板渲染器配置
---@return lib.template.renderer
function M.create_template_renderer(args)
    assert(args == nil or type(args) == "table", "template renderer args must be table")
    args = args or {}
    args.exposed_contexts = args.exposed_contexts or {}
    assert(type(args.exposed_contexts) == "table", "template renderer exposed_contexts must be table")
    assert(args.value_reader == nil or type(args.value_reader) == "function", "template renderer value_reader must be function")

    ---@class lib.template.renderer
    ---@operator call(string):string
    local renderer = {
        class_name = "lib.template.renderer",
    }

    function renderer.set_class(class_name)
        renderer.class_name = class_name
    end

    function renderer.is_instance_of(value, class_name)
        return type(value) == "table" and (value.class_name == class_name or value.type == class_name)
    end

    renderer.exposed_contexts = create_collection({
        reversed = true,
    })

    renderer.placeholder_renderers = create_collection({
        compare = function(a, b)
            return a.priority() < b.priority()
        end,
    })

    ---@param stage lib.template.placeholder_renderer_stage
    ---@return table
    local function get_placeholder_renderers(stage)
        return renderer.placeholder_renderers.filter(function(item)
            return item.stage() == stage
        end)
    end

    ---@param context table
    local function render_token_placeholder(context)
        local ordered_stages = {
            "format",
            "locale",
            "coloring",
        }

        for _, stage in ipairs(ordered_stages) do
            get_placeholder_renderers(stage).for_each(function(item)
                item.on_render(context)
            end)
        end
    end

    ---@param entry table
    local function render_join_placeholder(entry)
        local has_matched = false

        get_placeholder_renderers("join").for_each(function(item, foreach_context)
            item.on_render(entry)
            has_matched = true
            foreach_context.stop()
        end)

        if not has_matched then
            entry.value = tablex.concat(entry.values, "")
        end
    end

    ---@param placeholder string
    ---@return table? entry 找到时返回占位符条目
    local function search_exposed(placeholder)
        local entry

        renderer.exposed_contexts.for_each(function(exposed_context, foreach_context)
            entry = exposed_context.find(placeholder)
            if entry == nil then
                return
            end
            foreach_context.stop()
        end)

        return entry
    end

    ---@param entry table
    local function render_list_entry(entry)
        local rendered_values = {}

        for index, value in ipairs(entry.values) do
            local token_entry = tablex.clone(entry)
            token_entry.value = value
            token_entry.values = nil
            render_token_placeholder(token_entry)
            rendered_values[index] = tostring(token_entry.value or "")
        end

        entry.values = rendered_values
        render_join_placeholder(entry)
    end

    ---@param placeholder string
    ---@return string
    local function render_placeholder(placeholder)
        local entry = search_exposed(placeholder)
        if entry == nil then
            return stringx.format("{%s}", placeholder)
        end

        if entry.values ~= nil then
            render_list_entry(entry)
        else
            render_token_placeholder(entry)
        end

        return tostring(entry.value or "")
    end

    ---@param template_text string
    ---@return string
    function renderer.run(template_text)
        assert(type(template_text) == "string", "template text must be string")
        return stringx.render_placeholders(template_text, render_placeholder)
    end

    ---@return string[]
    function renderer.get_exposed_fields()
        local fields = {}

        renderer.exposed_contexts.for_each(function(exposed_context)
            local sub_fields = exposed_context.get_prop_fields()
            local context_name = exposed_context.name
            if type(context_name) == "function" then
                context_name = context_name()
            end
            context_name = tostring(context_name or "")
            for _, sub_field in ipairs(sub_fields) do
                fields[#fields + 1] = context_name .. ":" .. tostring(sub_field)
            end
        end)

        return fields
    end

    local function normalize_exposed_context(exposed_context)
        if type(exposed_context.find) == "function" and type(exposed_context.get_prop_fields) == "function" then
            return exposed_context
        end
        return M.create_table_context({
            input = exposed_context,
            value_reader = args.value_reader,
        })
    end

    for _, exposed_context in ipairs(args.exposed_contexts) do
        renderer.exposed_contexts.add(normalize_exposed_context(exposed_context))
    end

    metatablex.callable(renderer, renderer.run)

    return renderer
end

return M
