---@type lib.metatablex
local metatable = require "lib.metatablex"
---@class lib.motion
local M = require "lib.motion"
---@type lib.reactive
local reactive = require "lib.reactive"

---@type table<lib.motion.modifier.phase, integer>
local PHASE_ORDER = {
    normal = 1,
    post = 2,
}

---@param modifier lib.motion.modifier
---@return boolean
local function is_modifier(modifier)
    return type(modifier) == "table" and type(modifier.run) == "function"
end

---@param a lib.motion.modifier
---@param b lib.motion.modifier
---@return boolean
local function compare_modifier(a, b)
    local a_phase = PHASE_ORDER[a.phase] or PHASE_ORDER.normal
    local b_phase = PHASE_ORDER[b.phase] or PHASE_ORDER.normal
    if a_phase ~= b_phase then
        return a_phase < b_phase
    end

    if a.exclusive ~= b.exclusive then
        return a.exclusive == true
    end

    if a.priority ~= b.priority then
        return a.priority < b.priority
    end

    return false
end

---@class lib.motion.renderer.options: lib.reactive.factory.options
---@field dt? number 字段说明
---@field reset_z? number 字段说明
---@field reset_on_empty? boolean 字段说明
---@field reset_height? fun(args:lib.motion.reset_height.args) 字段说明

---@class lib.motion.reset_height.args
---@field reason string 复位原因
---@field z number 复位目标高度
---@field modifier? lib.motion.modifier 字段说明
---@param args? lib.motion.renderer.options 参数说明
---@return lib.motion.renderer
function M.renderer(args)
    args = args or {}
    local dt = args.dt or 0
    local reset_z = args.reset_z or 0
    local reset_height = args.reset_height
    assert(type(dt) == "number", "motion renderer dt must be a number")
    assert(type(reset_z) == "number", "motion renderer reset_z must be a number")
    assert(reset_height == nil or type(reset_height) == "function", "motion renderer reset_height must be a function")

    ---@class lib.motion.renderer : lib.reactive.factory
    local o = reactive.factory(args)
    o.factory.set_class("lib.motion.renderer")

    o.factory.collection_field("modifiers", {
        name = "modifiers",
        compare = compare_modifier,
        prevent_duplicate = true,
        item_checker = is_modifier,
    })

    o.dt = dt
    o.reset_z = reset_z
    o.reset_on_empty = args.reset_on_empty or false
    o.factory.event_field("on_update", { name = "update" })
    o.factory.event_field("before_render", { name = "before_render" })
    o.factory.event_field("after_resolve", { name = "after_resolve" })
    o.factory.event_field("on_complete", { name = "complete" })
    o.factory.event_field("on_active_interrupt", { name = "active_interrupt" })
    o.factory.event_field("on_passive_interrupt", { name = "passive_interrupt" })
    o.on_interrupt = o.on_passive_interrupt
    o.factory.event_field("on_reset_height", { name = "reset_height" })
    o.factory.field("loop_scope").scope({ name = "loop" })

    ---@param reason string
    ---@param modifier? lib.motion.modifier 参数说明
    ---@param result? lib.motion.result 参数说明
    function o.reset_height(reason, modifier, result)
        local reset_args = {
            reason = reason,
            z = o.reset_z,
            modifier = modifier,
            result = result,
        }
        o.on_reset_height(reset_args)
        if reset_height ~= nil then
            reset_height(reset_args)
        end
    end

    ---@param modifier lib.motion.modifier
    ---@param reason string
    ---@param source? lib.motion.modifier 参数说明
    function o.interrupt_modifier(modifier, reason, source)
        if modifier.interrupted or modifier.finished then
            return
        end
        if source ~= nil and source.active_interrupt ~= nil then
            source.active_interrupt(reason, modifier)
            o.on_active_interrupt(source, modifier, reason)
        end
        modifier.passive_interrupt(reason, source)
        o.on_passive_interrupt(modifier, source, reason)
        if modifier.reset_on_interrupt then
            o.reset_height(reason, modifier)
        end
    end

    ---@param interrupt_args? { 参数说明
    function o.interrupt_all(interrupt_args)
        interrupt_args = interrupt_args or {}
        local reason = interrupt_args.reason or "interrupt_all"
        local should_reset = interrupt_args.reset or false
        local source = interrupt_args.source
        local did_interrupt = false

        o.modifiers().for_each(function(modifier)
            if source == modifier then
                return
            end
            if not modifier.interrupted and not modifier.finished then
                did_interrupt = true
                if source ~= nil and source.active_interrupt ~= nil and source ~= modifier then
                    source.active_interrupt(reason, modifier)
                    o.on_active_interrupt(source, modifier, reason)
                end
                modifier.passive_interrupt(reason, source)
                o.on_passive_interrupt(modifier, source, reason)
                should_reset = should_reset or modifier.reset_on_interrupt
            end
        end)

        if did_interrupt and should_reset then
            o.reset_height(reason)
        end
    end

    ---@param modifier lib.motion.modifier
    ---@return fun()
    function o.add(modifier)
        if modifier.interrupt_previous then
            o.interrupt_all({
                reason = "interrupt_previous",
                reset = modifier.reset_before_start,
                source = modifier,
            })
        end
        local remove = o.modifiers.add(modifier)
        o.factory.delete.mount(remove)
        if modifier.delete ~= nil and modifier.delete.mount ~= nil then
            modifier.delete.mount(remove)
        end
        return remove
    end

    ---@param args? lib.motion.modifier.options 参数说明
    ---@return lib.motion.modifier
    function o.create_modifier(args)
        local modifier = M.modifier(args)
        o.add(modifier)
        return modifier
    end

    function o.clear()
        o.modifiers.clear()
    end

    ---@param args? table 参数说明
    ---@return lib.motion.data
    function o.create_data(args)
        if args == nil then
            return M.data({ dt = o.dt, reset_z = o.reset_z })
        end
        if args.dt ~= nil then
            return M.data(args)
        end
        local data_args = {}
        for key, value in pairs(args) do
            data_args[key] = value
        end
        data_args.dt = o.dt
        data_args.reset_z = data_args.reset_z or o.reset_z
        return M.data(data_args)
    end

    ---@param args? table|lib.motion.data 参数说明
    ---@return lib.motion.result
    function o.render(args)
        local data = o.create_data(args)
        local had_modifiers = not o.modifiers.empty()
        local should_reset_on_empty = o.reset_on_empty
        o.before_render(data)

        o.modifiers().for_each(function(modifier, context)
            local did_run = modifier.run(data)
            if did_run and modifier.exclusive then
                context.stop()
            end
        end)

        local result = M.resolve(data)
        o.after_resolve(result)

        o.modifiers().for_each(function(modifier)
            local was_finished = modifier.finished
            local was_interrupted = modifier.interrupted
            modifier.complete(result)
            if not was_finished and not was_interrupted and modifier.finished and modifier.reset_on_finish then
                should_reset_on_empty = true
            end
        end)

        if had_modifiers and o.modifiers.empty() and should_reset_on_empty then
            o.reset_height("empty", nil, result)
        end

        o.on_complete(result)
        return result
    end

    o.tick = o.render

    function o.stop()
        o.loop_scope()
        o.factory.field("loop_scope").scope({ name = "loop" })
    end

    ---@param get_data? fun():table|lib.motion.data|nil 参数说明
    ---@return fun()
    function o.start(get_data)
        assert(get_data == nil or type(get_data) == "function", "motion renderer start get_data must be a function")

        o.stop()
        o.factory.timer(function()
            local args = nil
            if get_data ~= nil then
                args = get_data()
            end
            o.render(args)
        end, o.loop_scope)

        return o.stop
    end

    o.on_update.add(function(args)
        o.render(args)
    end)

    metatable.callable(o, o.render)

    return o
end

return M
