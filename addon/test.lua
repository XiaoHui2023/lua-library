local source = debug.getinfo(1, "S").source
local addon_dir = source:sub(1, 1) == "@" and source:sub(2) or source
addon_dir = addon_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = addon_dir:match("^(.*)[/\\][^/\\]+$") or addon_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local addon = require "addon"

local function assert_same(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_same") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

local function assert_order(actual, expected, message)
    assert_same(#actual, #expected, message .. " count")
    for index, value in ipairs(expected) do
        assert_same(actual[index], value, message .. " index " .. index)
    end
end

local load_order = {}
local activation_count = 0
local cleanup_count = 0

local high_priority = addon({
    name = "test.high_priority",
    priority = addon.PRIORITY.MODELS,
})

local dependency = addon({
    name = "test.dependency",
})

local dependent = addon({
    name = "test.dependent",
    dependencies = {
        dependency,
    },
})

high_priority.on_initialize.add(function()
    load_order[#load_order + 1] = high_priority.name()
end)

dependency.on_initialize.add(function()
    load_order[#load_order + 1] = dependency.name()
end)

dependent.on_initialize.add(function()
    load_order[#load_order + 1] = dependent.name()
end)

dependent.bind_activation(function()
    activation_count = activation_count + 1
    return function()
        cleanup_count = cleanup_count + 1
    end
end)

local ordered_names = {}
addon.for_each(function(item)
    if item.name():find("^test%.") then
        ordered_names[#ordered_names + 1] = item.name()
    end
end)

assert_order(ordered_names, {
    "test.high_priority",
    "test.dependency",
    "test.dependent",
}, "addon order")

addon.initialize_all()
assert_order(load_order, {
    "test.high_priority",
    "test.dependency",
    "test.dependent",
}, "initialize order")
assert_same(activation_count, 1, "initial activation should run")
assert_same(cleanup_count, 0, "cleanup should not run before deactivation")

addon.initialize_all()
assert_same(#load_order, 3, "initialize_all should be idempotent")
assert_same(activation_count, 1, "idempotent initialize should not reactivate")

dependent.is_enabled.set(false)
assert_same(cleanup_count, 1, "deactivation cleanup should run")
dependent.is_enabled.set(true)
assert_same(activation_count, 2, "reactivation should run")
dependent.is_enabled.set(false)
assert_same(cleanup_count, 2, "reactivation cleanup should be mounted again")

local cycle_b = addon({
    name = "test.cycle_b",
    dependencies = {
        dependent,
    },
})
cycle_b.dependencies[1] = cycle_b

local ok, err = pcall(function()
    addon.get_addons()
end)
assert(not ok and tostring(err):find("addon dependency cycle", 1, true), "cycle should be rejected")

print("addon test ok")
