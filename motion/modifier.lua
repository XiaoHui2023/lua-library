---@type lib.metatablex
local metatable = require "lib.metatablex"
---@class lib.motion
local M = require "lib.motion.base"
---@type lib.reactive
local reactive = require "lib.reactive"

---@alias lib.motion.modifier.phase
---| "normal"
---| "post"

local VALID_PHASE = {
    normal = true,
    post = true,
}

---@param value any
---@param name string
local function assert_optional_function(value, name)
    assert(value == nil or type(value) == "function", "motion modifier " .. name .. " must be a function")
end

---@class lib.motion.modifier.options
---@field name? string
---@field enabled? boolean
---@field phase? lib.motion.modifier.phase
---@field priority? integer
---@field exclusive? boolean
---@field modify? fun(data:lib.motion.data)
---@field tick? fun(data:lib.motion.data)
---@field should_run? fun(data:lib.motion.data):boolean
---@field should_finish? fun(data:lib.motion.data,result:lib.motion.result):boolean

---@param args? lib.motion.modifier.options
---@return lib.motion.modifier
function M.modifier(args)
    args = args or {}
    local phase = args.phase or "normal"
    local priority = args.priority or 0
    local modify = args.modify or args.tick or function()
    end

    assert(VALID_PHASE[phase], "motion modifier phase must be normal or post")
    assert(type(priority) == "number", "motion modifier priority must be a number")
    assert(type(modify) == "function", "motion modifier modify must be a function")
    assert_optional_function(args.should_run, "should_run")
    assert_optional_function(args.should_finish, "should_finish")

    ---@class lib.motion.modifier : lib.motion.modifier.options
    local o = {
        name = args.name or "",
        enabled = args.enabled ~= false,
        phase = phase,
        priority = priority,
        exclusive = args.exclusive or false,
    }

    o.modify = modify
    o.tick = modify
    o.should_run = args.should_run or function()
        return true
    end
    o.should_finish = args.should_finish or function()
        return false
    end

    o.delete = reactive.once_event({ name = o.name .. ".delete" })
    o.before_modify = reactive.event({ name = o.name .. ".before_modify" })
    o.after_modify = reactive.event({ name = o.name .. ".after_modify" })
    o.after_render = reactive.event({ name = o.name .. ".after_render" })
    o.on_finish = reactive.once_event({ name = o.name .. ".finish" })

    ---@param data lib.motion.data
    ---@return boolean
    function o.run(data)
        if not o.enabled then
            return false
        end
        if not o.should_run(data) then
            return false
        end

        o.before_modify(data)
        o.modify(data)
        o.after_modify(data)
        return true
    end

    ---@param result lib.motion.result
    function o.complete(result)
        o.after_render(result)
        if o.should_finish(result.data, result) then
            o.on_finish(result)
            o.delete()
        end
    end

    ---@param renderer lib.motion.renderer
    ---@return fun()
    function o.inject(renderer)
        return renderer.add(o)
    end

    o.attach = o.inject

    metatable.callable(o, o.run)

    return o
end

return M
