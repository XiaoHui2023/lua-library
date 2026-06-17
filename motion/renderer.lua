---@type lib.metatablex
local metatable = require "lib.metatablex"
---@class lib.motion
local M = require "lib.motion.base"
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
---@field dt? number

---@param args? lib.motion.renderer.options
---@return lib.motion.renderer
function M.renderer(args)
    args = args or {}
    local dt = args.dt or 0
    assert(type(dt) == "number", "motion renderer dt must be a number")

    ---@class lib.motion.renderer : lib.reactive.factory
    local o = reactive.factory(args)
    o.set_class("lib.motion.renderer")

    o.modifiers = o.factory.add({
        name = "modifiers",
        compare = compare_modifier,
        prevent_duplicate = true,
        item_checker = is_modifier,
    })

    o.dt = dt
    o.on_update = o.factory.event({ name = "update" })
    o.before_render = o.factory.event({ name = "before_render" })
    o.after_resolve = o.factory.event({ name = "after_resolve" })
    o.on_complete = o.factory.event({ name = "complete" })
    o.loop_scope = o.factory.delete({ name = "loop" })

    ---@param modifier lib.motion.modifier
    ---@return fun()
    function o.add(modifier)
        local remove = o.modifiers.add(modifier)
        o.delete.mount(remove)
        if modifier.delete ~= nil and modifier.delete.mount ~= nil then
            modifier.delete.mount(remove)
        end
        return remove
    end

    ---@param args? lib.motion.modifier.options
    ---@return lib.motion.modifier
    function o.create_modifier(args)
        local modifier = M.modifier(args)
        o.add(modifier)
        return modifier
    end

    function o.clear()
        o.modifiers.clear()
    end

    ---@param args? table
    ---@return lib.motion.data
    function o.create_data(args)
        if args == nil then
            return M.data({ dt = o.dt })
        end
        if args.dt ~= nil then
            return M.data(args)
        end
        local data_args = {}
        for key, value in pairs(args) do
            data_args[key] = value
        end
        data_args.dt = o.dt
        return M.data(data_args)
    end

    ---@param args? table|lib.motion.data
    ---@return lib.motion.result
    function o.render(args)
        local data = o.create_data(args)
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
            modifier.complete(result)
        end)

        o.on_complete(result)
        return result
    end

    o.tick = o.render

    function o.stop()
        o.loop_scope()
        o.loop_scope = o.factory.delete({ name = "loop" })
    end

    ---@param get_data? fun():table|lib.motion.data|nil
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
