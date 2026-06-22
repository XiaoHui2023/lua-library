local source = debug.getinfo(1, "S").source
local module_dir = source:sub(1, 1) == "@" and source:sub(2) or source
module_dir = module_dir:match("^(.*)[/\\][^/\\]+$") or "."
local lib_root = module_dir:match("^(.*)[/\\][^/\\]+$") or module_dir
local script_root = lib_root:match("^(.*)[/\\][^/\\]+$") or lib_root
package.path = script_root .. "/?.lua;" .. script_root .. "/?/init.lua;" .. script_root .. "/lib/?.lua;" .. script_root .. "/lib/?/init.lua;" .. package.path

local motion = require "lib.motion"

local resets = 0
local interrupted = 0
local active_interrupted = 0
local passive_interrupted = 0

local renderer = motion.renderer({
    dt = 0.03,
    reset_z = 0,
    reset_on_empty = true,
    reset_height = function()
        resets = resets + 1
    end,
})

local first = renderer.create_modifier({
    name = "first",
    reset_on_interrupt = true,
    modify = function(data)
        data.delta_z = data.delta_z + 100
    end,
    on_interrupt = function()
        interrupted = interrupted + 1
    end,
    on_passive_interrupt = function()
        passive_interrupted = passive_interrupted + 1
    end,
})

renderer.render({ origin_z = 0 })
assert(first.interrupted == false, "first should still be active")

local second = renderer.create_modifier({
    name = "second",
    interrupt_previous = true,
    reset_before_start = true,
    modify = function(data)
        data.delta_z = data.delta_z + 20
    end,
    should_finish = function()
        return true
    end,
    on_active_interrupt = function()
        active_interrupted = active_interrupted + 1
    end,
})

assert(first.interrupted == true, "first should be interrupted")
assert(second.interrupted == false, "second should not be interrupted by its active interrupt")
assert(interrupted == 1, "first interrupt callback should run once")
assert(passive_interrupted == 1, "first passive interrupt callback should run once")
assert(active_interrupted == 1, "second active interrupt callback should run once")
assert(resets == 1, "interrupt should reset height once")

renderer.render({ origin_z = 0 })
assert(renderer.modifiers.empty(), "finished modifier should be removed")
assert(resets == 2, "empty renderer should reset height once")

renderer.create_modifier({
    name = "third",
    modify = function()
    end,
})

renderer.interrupt_all({ reason = "unit_dead", reset = true })
assert(renderer.modifiers.empty(), "interrupt_all should remove all modifiers")
assert(resets == 3, "interrupt_all should reset height")

local finish_resets = 0
local renderer_finish = motion.renderer({
    reset_height = function()
        finish_resets = finish_resets + 1
    end,
})

renderer_finish.create_modifier({
    name = "finish_reset",
    reset_on_finish = true,
    modify = function()
    end,
    should_finish = function()
        return true
    end,
})

renderer_finish.render()
assert(finish_resets == 1, "reset_on_finish should reset when renderer becomes empty")
