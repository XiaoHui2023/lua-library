local source = debug.getinfo(1, "S").source
local list_dir = source:sub(1, 1) == "@" and source:sub(2) or source
list_dir = list_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = list_dir:match("^(.*)[/\\][^/\\]+$") or list_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local list = require "list"

local function same_array(actual, expected, message)
    assert(#actual == #expected, (message or "array length") .. ": got " .. #actual .. ", want " .. #expected)
    for i = 1, #expected do
        assert(actual[i] == expected[i], (message or "array value") .. "[" .. i .. "]: got " .. tostring(actual[i]) .. ", want " .. tostring(expected[i]))
    end
end

local l = list({ "a", "b", "c" })
assert(l.count == 3, "constructor should append initial values")
assert(l.index(2) == "b", "index should return value by rank")
same_array(l.to_table(), { "a", "b", "c" }, "to_table should preserve order")

local false_list = list({ false })
assert(false_list.index(1) == false, "index should preserve false element")
assert(false_list.contains(false), "contains should preserve false element")
assert(false_list.pop_front() == false, "pop_front should preserve false element")

local delete_b = l.insert(2, "x")
same_array(l.to_table(), { "a", "x", "b", "c" }, "insert should place value at rank")
delete_b()
same_array(l.to_table(), { "a", "b", "c" }, "delete handler should remove inserted value once")
delete_b()
same_array(l.to_table(), { "a", "b", "c" }, "delete handler should be idempotent")

local old_delete = l.append("old")
l.clear()
l.append("new")
old_delete()
same_array(l.to_table(), { "new" }, "old delete handler should not remove entries created after clear")

l = list({ 1, 2, 3, 4 })
local seen = {}
l.for_each(function(value, ctx)
    seen[#seen + 1] = value
    if value == 2 then
        ctx.remove()
    elseif value == 3 then
        ctx.set(30)
    elseif value == 4 then
        ctx.stop()
    end
end)
same_array(seen, { 1, 2, 3, 4 }, "for_each should visit snapshot entries")
same_array(l.to_table(), { 1, 30, 4 }, "for_each context should remove and set current entry")

local records = list({
    { group = 1, name = "a" },
    { group = 2, name = "b" },
    { group = 1, name = "c" },
    { group = 2, name = "d" },
})
records.sort(function(a, b)
    return a.group < b.group
end)
local names = records.map(function(item)
    return item.name
end)
same_array(names.to_table(), { "a", "c", "b", "d" }, "sort should be stable")

records.sort(function(a, b)
    return a.group < b.group
end, true)
names = records.map(function(item)
    return item.name
end)
same_array(names.to_table(), { "b", "d", "a", "c" }, "reverse sort should keep equal items stable")

l = list({ 1, 2, 3, 4 })
l.sort(nil, true)
same_array(l.to_table(), { 4, 3, 2, 1 }, "sort without comparator should support reverse")

l = list({ 1, 2, 3, 4 })
same_array(l.slice(-10, 2).to_table(), { 1, 2 }, "slice should clamp low start")
same_array(l.slice(3, 99).to_table(), { 3, 4 }, "slice should clamp high stop")
same_array(list().slice(1).to_table(), {}, "empty slice should return empty list")
l.shuffle(2)
assert(l.count == 4, "shuffle should keep item count")

assert(not pcall(function()
    l.index(1.5)
end), "index should reject non-integer rank")
assert(not pcall(function()
    l.pop("1")
end), "pop should reject non-number rank")
assert(not pcall(function()
    l.slice("1", 2)
end), "slice should reject non-number start")
assert(not pcall(function()
    l.slice(1, false)
end), "slice should reject non-number stop")
assert(not pcall(function()
    list().slice("1", 2)
end), "empty slice should still reject non-number start")
assert(not pcall(function()
    l.shuffle(1.5)
end), "shuffle should reject non-integer limit")
assert(not pcall(function()
    l.shuffle(false)
end), "shuffle should reject non-number limit")
assert(not pcall(function()
    l.for_each(nil)
end), "for_each should reject non-function callback")
assert(not pcall(function()
    l.filter(nil)
end), "filter should reject non-function predicate")
assert(not pcall(function()
    l.map(nil)
end), "map should reject non-function mapper")
assert(not pcall(function()
    l.sort(true)
end), "sort should reject non-function comparator")
assert(not pcall(function()
    l.sort(nil, "true")
end), "sort should reject non-boolean reverse")

l.set_debug_mode(false)
assert(not l.get_debug_mode(), "debug mode count should not become negative")
l.set_debug_mode(true)
l.set_debug_mode(true)
l.set_debug_mode(false)
assert(l.get_debug_mode(), "debug mode should stay enabled until all enables are released")
l.set_debug_mode(false)
assert(not l.get_debug_mode(), "debug mode should disable after matching releases")
assert(not pcall(function()
    l.set_debug_mode(nil)
end), "set_debug_mode should reject non-boolean enable")

local ok = pcall(list, { 1, nil, 3 })
assert(not ok, "constructor should reject array holes")
ok = pcall(list, false)
assert(not ok, "constructor should reject non-table source")

print("list test ok")
