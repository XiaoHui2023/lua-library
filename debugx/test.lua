local source = debug.getinfo(1, "S").source
local debugx_dir = source:sub(1, 1) == "@" and source:sub(2) or source
debugx_dir = debugx_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = debugx_dir:match("^(.*)[/\\][^/\\]+$") or debugx_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local debugx = require "debugx"

assert(debugx.dump(nil) == "nil", "dump nil should be explicit")
assert(debugx.load(debugx.dump(nil)) == nil, "dump nil should load back to nil")
assert(debugx.dump({ "a", "b" }) == '{"a","b"}', "dump array should use compact array syntax")
assert(debugx.dump({ b = 2, a = 1 }) == '{["a"]=1,["b"]=2}', "dump object should be stable")

local cyclic = { name = "root" }
cyclic.self = cyclic
local cyclic_text = debugx.dump(cyclic)
assert(cyclic_text:find("<cycle:", 1, true) ~= nil, "dump should mark cyclic references")
assert(type(debugx.load(cyclic_text)) == "table", "load should accept dump with cycle marker string")
assert(type(debugx.load("not valid lua")) == "table", "load should return empty table on invalid input")

local printed = {}
local raw_print = print
---@param ... any 捕获测试输出参数
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    printed[#printed + 1] = table.concat(parts, "\t")
end

local ok, err = pcall(function()
    debugx.print({ child = { value = 1 } })
end)
print = raw_print
assert(ok, err)

assert(printed[1]:find("^table: .* {$") ~= nil, "print should start with one table header")
assert(printed[2]:find("^  %[\"child\"%] => table: .* {$") ~= nil, "print should put nested table header on key line")
assert(printed[3] == '    ["value"] => 1', "print should indent nested values")
assert(printed[4] == "  }", "print should close nested table")
assert(printed[5] == "}", "print should close root table")

local messages = {}
local logs = {}
debugx.set_backend({
    debug = function(...)
        logs[#logs + 1] = { level = "debug", value = table.concat({ ... }, "\t") }
    end,
    info = function(...)
        logs[#logs + 1] = { level = "info", value = table.concat({ ... }, "\t") }
    end,
    warn = function(...)
        logs[#logs + 1] = { level = "warn", value = table.concat({ ... }, "\t") }
    end,
    error = function(msg)
        messages[#messages + 1] = msg
    end,
    get_debug_mode = function()
        return true
    end,
})

assert(debugx.get_debug_mode(), "get_debug_mode should use backend")
debugx.debug("debug", 1)
debugx.info("info", 2)
debugx.warn("warn", 3)
assert(#logs == 3, "log backends should be called")
assert(logs[1].level == "debug" and logs[1].value == "debug\t1", "debug should forward varargs")
assert(logs[2].level == "info" and logs[2].value == "info\t2", "info should forward varargs")
assert(logs[3].level == "warn" and logs[3].value == "warn\t3", "warn should forward varargs")
debugx.error("boom")
assert(#messages == 1, "error backend should be called once")
assert(messages[1]:find("boom", 1, true) ~= nil, "error should include message")
assert(messages[1]:find("stack traceback", 1, true) ~= nil, "error should include traceback")

debugx.set_backend({
    get_debug_mode = function()
        return false
    end,
})
debugx.debug("hidden")
assert(#logs == 3, "debug should be filtered when debug mode is disabled")

local ok = pcall(debugx.set_backend, { error = "bad" })
assert(not ok, "set_backend should reject invalid error backend")

print("debugx test ok")
