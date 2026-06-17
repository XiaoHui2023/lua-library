---依赖收集与循环依赖检测

local M = {}

---@type { model: table, deps: table<table, number> }[]
local context_stack = {}

local function pack_values(...)
    return {
        n = select("#", ...),
        ...,
    }
end

---@param model table
function M.register(model)
    if model.is_disposed and model.is_disposed() then
        return
    end

    local ctx = context_stack[#context_stack]
    if ctx == nil then
        return
    end

    for i = #context_stack, 1, -1 do
        if context_stack[i].model == model then
            local names = {}
            for j = i, #context_stack do
                local name = context_stack[j].model.get_name and context_stack[j].model.get_name() or ""
                if name == "" then
                    name = tostring(context_stack[j].model)
                end
                table.insert(names, name)
            end
            error(string.format("circular dependency: %s", table.concat(names, " -> ")))
        end
    end

    ctx.deps[model] = model.get_version()
end

---@param model table
---@param fn fun(): ...
---@return table, table<table, number>
function M.run(model, fn)
    local ctx = {
        model = model,
        deps = {},
    }
    table.insert(context_stack, ctx)
    local values
    local ok, result = xpcall(function()
        values = pack_values(fn())
    end, debug.traceback)
    table.remove(context_stack)
    if not ok then
        error(result, 0)
    end
    return values, ctx.deps
end

---@param deps table<table, number>
---@return boolean
function M.is_stale(deps)
    for dep, version in pairs(deps) do
        if dep.is_disposed and dep.is_disposed() then
            return true
        end
        if dep.is_dirty and dep.is_dirty() then
            return true
        end
        if dep.get_version() ~= version then
            return true
        end
    end
    return false
end

return M
