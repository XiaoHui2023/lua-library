local source = debug.getinfo(1, "S").source
local module_dir = source:sub(1, 1) == "@" and source:sub(2) or source
module_dir = module_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = module_dir:match("^(.*)[/\\][^/\\]+$") or module_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local module = require "module"
local system = module.system
local composition = module.composition
local addon = module.addon

local function assert_same(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_same") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

local system_order = {}
system({
    id = "test.system.dependency",
    priority = system.PRIORITY.FRAMEWORK + 20,
    init = function()
        system_order[#system_order + 1] = "dependency"
    end,
})
system({
    id = "test.system.dependent",
    dependencies = {
        "test.system.dependency",
    },
    priority = system.PRIORITY.FRAMEWORK + 10,
    init = function()
        system_order[#system_order + 1] = "dependent"
    end,
})

system.initialize_all()
assert_same(table.concat(system_order, ","), "dependency,dependent", "system dependency order")
system.initialize_all()
assert_same(#system_order, 2, "system initialize_all should be idempotent")

local compose_order = {}
composition({
    id = "test.composition.profile",
    priority = composition.PRIORITY.PROFILE,
    compose = function()
        compose_order[#compose_order + 1] = "profile"
    end,
})
composition({
    id = "test.composition.scene",
    dependencies = {
        "test.composition.profile",
    },
    priority = composition.PRIORITY.SCENE,
    compose = function()
        compose_order[#compose_order + 1] = "scene"
    end,
})

composition.compose_all()
assert_same(table.concat(compose_order, ","), "profile,scene", "composition dependency order")
composition.compose_all()
assert_same(#compose_order, 2, "composition compose_all should be idempotent")

local activation_count = 0
local cleanup_count = 0
local addon_dependency = addon({
    id = "test.addon.dependency",
    name = "Dependency Addon",
})
assert_same(addon_dependency.name(), "Dependency Addon", "addon should expose name")
local addon_dependent = addon({
    id = "test.addon.dependent",
    name = "Dependent Addon",
    dependencies = {
        "test.addon.dependency",
    },
})

addon_dependent.bind_activation(function()
    activation_count = activation_count + 1
    return function()
        cleanup_count = cleanup_count + 1
    end
end)

addon.initialize_all()
assert_same(activation_count, 1, "addon should activate after dependencies initialize")
addon_dependency.is_enabled.set(false)
assert_same(addon_dependent.is_active(), false, "addon dependency disable should deactivate dependent")
assert_same(cleanup_count, 1, "addon dependency disable should run cleanup")
addon_dependency.is_enabled.set(true)
assert_same(activation_count, 2, "addon dependency enable should reactivate dependent")

print("module test ok")
