local source = debug.getinfo(1, "S").source
local module_dir = source:sub(1, 1) == "@" and source:sub(2) or source
module_dir = module_dir:match("^(.*)[/\\][^/\\]+$") or "."
local framework_root = module_dir:match("^(.*)[/\\][^/\\]+$") or module_dir
local script_root = framework_root:match("^(.*)[/\\][^/\\]+$") or framework_root
package.path = script_root .. "/?.lua;" .. script_root .. "/?/init.lua;" .. script_root .. "/lib/?.lua;" .. script_root .. "/lib/?/init.lua;" .. package.path

local state_machine = require "lib.state_machine"

local machine = state_machine.machine({ name = "hero_state", owner = "hero" })
local log = {}

local block = state_machine.state({
    name = "block",
    machine = machine,
    on_entry = function()
        log[#log + 1] = "block_entry"
    end,
    on_exit = function(_, reason)
        log[#log + 1] = "block_exit:" .. tostring(reason)
    end,
})

local counter = block:transition_to({
    name = "counter",
    on_entry = function(_, context)
        log[#log + 1] = "counter_entry:" .. tostring(context.reason)
    end,
})

block:add_timer(1.0, function(state)
    state:done("timeout")
end)
block:on("attacked", function(state)
    state:done("counter")
end, { once = true })

block:start()
machine:update(0.4)
machine:emit("attacked", { damage = 10 })
assert(block:get_status() == "done", "block should be done when attacked")
assert(counter:get_status() == "running", "counter should start after block is done")
assert(log[1] == "block_entry", "block should enter")
assert(log[2] == "block_exit:counter", "block should exit with counter reason")
assert(log[3] == "counter_entry:counter", "counter should receive previous done reason")

local block_timeout = state_machine.state({
    name = "block_timeout",
    machine = machine,
})
block_timeout:add_timer(0.5, function(state)
    state:done("timeout")
end)
block_timeout:start()
machine:update(0.4)
assert(block_timeout:get_status() == "running", "timer should not finish early")
machine:update(0.2)
assert(block_timeout:get_status() == "done", "timer should finish after enough time")

local guarded = state_machine.state({
    name = "guarded",
    machine = machine,
})
local opened = guarded:add_transition({
    name = "opened",
}, {
    event = "open",
    guard = function(_, value)
        return value == true
    end,
})
guarded:start()
guarded:emit("open", false)
assert(opened:get_status() == "idle", "guard should block transition")
guarded:emit("open", true)
assert(guarded:get_status() == "done", "event transition should exit source state")
assert(opened:get_status() == "running", "guard should allow transition")

local caster = state_machine.state({
    name = "caster",
    machine = machine,
})
caster:start()
local projectile_ticks = 0
local projectile = caster:spawn({
    name = "projectile",
    on_update = function()
        projectile_ticks = projectile_ticks + 1
    end,
})
caster:interrupt("cast_cancel")
machine:update(0.1)
assert(caster:get_status() == "interrupted", "caster should be interrupted")
assert(projectile:get_status() == "running", "spawned projectile should keep running")
assert(projectile_ticks == 1, "spawned projectile should update through machine")

local parent = state_machine.state({
    name = "parent",
    machine = machine,
})
parent:start()
local child = parent:spawn_child({
    name = "child",
})
assert(child.parent == parent, "child should attach to parent")
assert(child:get_status() == "running", "spawn_child should auto start")
parent:interrupt("stun")
assert(child:get_status() == "interrupted", "child should be passively interrupted by parent")

local legacy_ran = false
local legacy = state_machine.create({
    name = "legacy_create",
    machine = machine,
    on_run = function(ctx)
        legacy_ran = ctx.state.name == "legacy_create" and ctx.machine == machine
        ctx.once_done()
    end,
})
legacy:start()
assert(legacy_ran, "create should support legacy on_run context")
assert(legacy:get_status() == "done", "legacy once_done should complete state")

state_machine.register_template("instant", function(args)
    args.on_run = function(ctx)
        ctx.once_done()
    end
    return state_machine.create(args)
end)
local tree_log = {}
local tree = state_machine.build_tree({
    {
        { key = "instant", name = "tree_a", on_exit = function() tree_log[#tree_log + 1] = "a" end },
        { key = "instant", name = "tree_b", on_exit = function() tree_log[#tree_log + 1] = "b" end },
    },
})
tree:start()
assert(tree:get_status() == "done", "build_tree should finish after children sequence")
assert(tree_log[1] == "a" and tree_log[2] == "b", "build_tree should run child states in order")

machine:destroy("owner_destroy")
assert(machine:is_destroyed(), "machine should be destroyed")
assert(projectile:is_destroyed(), "machine destroy should destroy spawned projectile")

print("framework state_machine test ok")
