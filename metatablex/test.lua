local source = debug.getinfo(1, "S").source
local metatablex_dir = source:sub(1, 1) == "@" and source:sub(2) or source
metatablex_dir = metatablex_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = metatablex_dir:match("^(.*)[/\\][^/\\]+$") or metatablex_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local metatablex = require "metatablex"

local shared_mt = {
    __index = {
        fallback = 10,
    },
}
local a = setmetatable({}, shared_mt)
local b = setmetatable({}, shared_mt)
metatablex.with_metatable(a, {
    __call = function()
        return "called"
    end,
})
assert(a.fallback == 10, "with_metatable should preserve old fields")
assert(a() == "called", "with_metatable should apply new fields")
assert(getmetatable(a) ~= shared_mt, "with_metatable should not mutate shared metatable")
assert(getmetatable(b) == shared_mt, "with_metatable should not affect other tables")

local locked_key = {}
metatablex.lock_new_fields(locked_key, "blocked")
local ok, err = pcall(function()
    locked_key.blocked = true
end)
assert(not ok and tostring(err):find("blocked", 1, true), "lock_new_fields should reject selected new key")
locked_key.allowed = true
assert(locked_key.allowed == true, "lock_new_fields should allow other new keys")

local locked_all = { exists = 1 }
metatablex.lock_new_fields(locked_all)
locked_all.exists = 2
assert(locked_all.exists == 2, "lock_new_fields should not block existing keys")
ok, err = pcall(function()
    locked_all.missing = 3
end)
assert(not ok and tostring(err):find("missing", 1, true), "lock_new_fields should reject any new key")

local proxy_source = { 1, 2, name = "source" }
local proxy = metatablex.readonly_proxy(proxy_source)
assert(proxy[1] == 1 and proxy.name == "source", "readonly_proxy should read from source")
assert(#proxy == 2, "readonly_proxy should forward length")
local seen_name = false
for key, value in pairs(proxy) do
    if key == "name" and value == "source" then
        seen_name = true
    end
end
assert(seen_name, "readonly_proxy should forward pairs")
ok, err = pcall(function()
    proxy.name = "changed"
end)
assert(not ok and tostring(err):find("readonly", 1, true), "readonly_proxy should reject writes")
assert(getmetatable(proxy) == false, "readonly_proxy should protect proxy metatable")

local called = metatablex.callable({}, function(a1, a2)
    return a1 + a2
end)
assert(called(2, 3) == 5, "callable should forward arguments without self")

local method_target = { value = 4 }
metatablex.callable_method(method_target, function(self, add)
    return self.value + add
end)
assert(method_target(6) == 10, "callable_method should pass self")

local named = { name = "first" }
metatablex.with_tostring(named, function(self)
    return "name:" .. self.name
end)
assert(tostring(named) == "name:first", "with_tostring should pass self")
named.name = "second"
assert(tostring(named) == "name:second", "with_tostring should stay dynamic")

local formatted = {}
metatablex.with_tostring_format(formatted, "id:%d", 7)
assert(tostring(formatted) == "id:7", "with_tostring_format should use captured format arguments")

local indexed = setmetatable({ raw = "raw" }, {
    __index = {
        base = "base",
    },
})
metatablex.index_proxy(indexed, function(_, key)
    if key == "virtual" then
        return "virtual"
    end
end)
assert(indexed.virtual == "virtual", "index_proxy should return proxy value")
assert(indexed.base == "base", "index_proxy should fall back to previous __index")
assert(indexed.raw == "raw", "index_proxy should not affect existing raw keys")

local protected = setmetatable({}, { __metatable = false })
ok, err = pcall(function()
    metatablex.with_metatable(protected, {})
end)
assert(not ok and tostring(err):find("protected", 1, true), "with_metatable should reject protected metatables")

print("metatablex test ok")
