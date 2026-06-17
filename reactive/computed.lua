---Lazy and scheduled computed reactive value.

local reactive_base = require "reactive.base"
local event = require "reactive.event"
local track = require "reactive.track"

local M = {}

local function pack_values(...)
    return {
        n = select("#", ...),
        ...,
    }
end

local function unpack_values(values)
    return table.unpack(values, 1, values.n or #values)
end

local function concat_values(first, second)
    local first_count = first.n or #first
    local second_count = second.n or #second
    local result = { n = first_count + second_count }
    for index = 1, first_count do
        result[index] = first[index]
    end
    for index = 1, second_count do
        local offset = first_count
        result[offset + index] = second[index]
    end
    return result
end

local function values_equal(new_values, old_values)
    local new_count = new_values.n or #new_values
    local old_count = old_values.n or #old_values
    if new_count ~= old_count then
        return false
    end
    for index = 1, new_count do
        if new_values[index] ~= old_values[index] then
            return false
        end
    end
    return true
end

---@type table[]
local frame_queue = {}
local frame_queued = setmetatable({}, { __mode = "k" })
local frame_flush_scheduled = false
---@type fun(flush: fun())|nil
local frame_scheduler = nil

local function request_frame_flush()
    if frame_scheduler == nil or frame_flush_scheduled then
        return
    end
    frame_flush_scheduled = true
    local ok, err = xpcall(function()
        frame_scheduler(function()
            frame_flush_scheduled = false
            M.flush_frame()
        end)
    end, debug.traceback)
    if not ok then
        frame_flush_scheduled = false
        error(err, 0)
    end
end

---@param model table
local function enqueue_frame(model)
    if frame_queued[model] then
        return
    end
    frame_queued[model] = true
    table.insert(frame_queue, model)
    request_frame_flush()
end

---@param scheduler fun(flush: fun())|nil
function M.set_frame_scheduler(scheduler)
    assert(scheduler == nil or type(scheduler) == "function", "computed frame scheduler must be a function")
    frame_scheduler = scheduler
    if frame_scheduler ~= nil and #frame_queue > 0 then
        request_frame_flush()
    end
end

---@return boolean
function M.has_frame_jobs()
    for index = #frame_queue, 1, -1 do
        local model = frame_queue[index]
        if model.is_disposed ~= nil and model.is_disposed() then
            frame_queued[model] = nil
            table.remove(frame_queue, index)
        end
    end
    return #frame_queue > 0
end

---@param max_rounds? integer
function M.flush_frame(max_rounds)
    max_rounds = max_rounds or 100
    frame_flush_scheduled = false

    local round = 0
    while #frame_queue > 0 do
        round = round + 1
        if round > max_rounds then
            error("computed frame flush exceeded max rounds")
        end

        local queue = frame_queue
        frame_queue = {}

        for _, model in ipairs(queue) do
            frame_queued[model] = nil
            if model.is_disposed == nil or not model.is_disposed() then
                model.recompute_if_dirty()
            end
        end
    end
end

---@param args { expr: fun():..., equals?: fun(...):boolean, auto?: boolean, flush?: "lazy"|"sync"|"frame", name?: string }
---@return table
function M.new(args)
    if type(args) == "function" then
        args = { expr = args }
    end
    args = args or {}
    assert(type(args.expr) == "function", "computed requires expr")

    local expr = args.expr
    local equals = args.equals
    local flush = args.flush or (args.auto and "sync") or "lazy"
    assert(flush == "lazy" or flush == "sync" or flush == "frame", "computed flush must be lazy, sync, or frame")

    local base = reactive_base.new({ name = args.name or "" })
    local on_update = event.new({ name = (args.name or "") .. ".update" })
    local on_change = event.new({ name = (args.name or "") .. ".change" })
    local on_dirty = event.new({ name = (args.name or "") .. ".dirty" })
    local on_dispose = event.new({ mode = "once", name = (args.name or "") .. ".dispose" })

    local cached = pack_values()
    local has_cache = false
    local is_dirty = true
    ---@type table<table, number>
    local deps = {}
    ---@type table<table, fun()>
    local dep_unsubs = {}
    local auto_update_unsub

    local o = {
        type = "computed",
        on_update = on_update.as_listener(),
        on_change = on_change.as_listener(),
        on_dirty = on_dirty.as_listener(),
        on_dispose = on_dispose.as_listener(),
    }

    local function clear_dep_unsubs()
        for _, unsub in pairs(dep_unsubs) do
            unsub()
        end
        dep_unsubs = {}
    end

    local function mark_dirty()
        if base.is_disposed() then
            return
        end
        if is_dirty then
            return
        end
        is_dirty = true
        on_dirty.run()
        if flush == "frame" then
            enqueue_frame(o)
        elseif flush == "sync" then
            o.recompute_if_dirty()
        end
    end

    local function setup_dep_subscriptions(new_deps)
        for dep, unsub in pairs(dep_unsubs) do
            if new_deps[dep] == nil then
                unsub()
                dep_unsubs[dep] = nil
            end
        end

        for dep in pairs(new_deps) do
            if dep_unsubs[dep] == nil then
                if dep.on_dirty ~= nil then
                    dep_unsubs[dep] = dep.on_dirty(mark_dirty)
                elseif dep.on_change ~= nil then
                    dep_unsubs[dep] = dep.on_change(mark_dirty)
                end
            end
        end
    end

    local function recompute_internal()
        local had_cache = has_cache
        local old_values = cached
        local new_values
        new_values, deps = track.run(o, expr)
        local all_values = concat_values(new_values, old_values)
        local is_equal = false
        if had_cache then
            if equals ~= nil then
                is_equal = equals(unpack_values(all_values))
            else
                is_equal = values_equal(new_values, old_values)
            end
        end
        has_cache = true
        is_dirty = false
        cached = new_values
        setup_dep_subscriptions(deps)
        on_update.run(unpack_values(all_values))
        if had_cache and not is_equal then
            base.touch()
            on_change.run(unpack_values(all_values))
        end
        return unpack_values(new_values)
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
        if base.is_disposed() then
            return unpack_values(cached)
        end
        o.track()
        if not has_cache or is_dirty or track.is_stale(deps) then
            local values = pack_values(recompute_internal())
            o.track()
            return unpack_values(values)
        end
        return unpack_values(cached)
    end

    function o.recompute()
        if base.is_disposed() then
            return unpack_values(cached)
        end
        return recompute_internal()
    end

    function o.recompute_if_dirty()
        if base.is_disposed() then
            return unpack_values(cached)
        end
        if has_cache and not is_dirty and not track.is_stale(deps) then
            return unpack_values(cached)
        end
        return recompute_internal()
    end

    function o.refresh()
        return o.recompute_if_dirty()
    end

    function o.try_update()
        return o.refresh()
    end

    function o.auto_update()
        if auto_update_unsub ~= nil then
            return auto_update_unsub
        end
        auto_update_unsub = on_dirty.add(function()
            o.recompute_if_dirty()
        end)
        o.recompute_if_dirty()
        return auto_update_unsub
    end

    function o.compute(new_expr)
        assert(type(new_expr) == "function", "computed compute requires expr")
        expr = new_expr
        clear_dep_unsubs()
        deps = {}
        is_dirty = true
        o.recompute_if_dirty()
    end

    function o.set(...)
        local fixed_values = pack_values(...)
        o.compute(function()
            return unpack_values(fixed_values)
        end)
    end

    function o.wrap_compute(wrapper)
        assert(type(wrapper) == "function", "computed wrapper must be a function")
        local old_expr = expr
        expr = function()
            return wrapper(old_expr())
        end
        is_dirty = true
        o.recompute_if_dirty()
    end

    function o.mark_dirty()
        mark_dirty()
    end

    function o.is_dirty()
        if base.is_disposed() then
            return false
        end
        return is_dirty or track.is_stale(deps)
    end

    function o.get_flush()
        return flush
    end

    function o.raw_get()
        return unpack_values(cached)
    end

    function o.dispose()
        if base.is_disposed() then
            return
        end
        on_dispose.run()
        on_update.clear()
        on_change.clear()
        on_dirty.clear()
        on_dispose.clear()
        clear_dep_unsubs()
        if auto_update_unsub ~= nil then
            auto_update_unsub()
            auto_update_unsub = nil
        end
        frame_queued[o] = nil
        cached = pack_values()
        has_cache = false
        is_dirty = true
        deps = {}
        base.mark_disposed()
    end

    function o.clear()
        o.dispose()
    end

    setmetatable(o, {
        __call = function()
            return o.get()
        end,
    })

    return o
end

return M
