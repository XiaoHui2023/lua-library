local source = debug.getinfo(1, "S").source
local requirex_dir = source:sub(1, 1) == "@" and source:sub(2) or source
requirex_dir = requirex_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = requirex_dir:match("^(.*)[/\\][^/\\]+$") or "."
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local requirex = require "requirex"
requirex.initial("requirex/test.lua")

local raw_require = require
local wrapped_require = requirex.reload(raw_require)
require = wrapped_require

assert(requirex.resolve("plain.module") == "plain.module", "plain module should not be rewritten")
assert(requirex.resolve(".fixture.parent") == "requirex.fixture.parent", "relative resolve should use caller directory")

local ok, err = pcall(function()
    requirex.resolve("...outside")
end)
assert(not ok and tostring(err):find("exceeds root", 1, true), "relative resolve should reject paths above root")

local external_chunk = assert(load("local resolved = requirex.resolve('.child'); return resolved", "@C:/outside/module.lua", "t", {
    requirex = requirex,
}))
local external_resolved = external_chunk()
assert(external_resolved == ".child", "absolute callers outside root should not be rewritten: " .. tostring(external_resolved))

local relative_chunk = assert(load("local resolved = requirex.resolve('.child'); return resolved", "@relative/module.lua", "t", {
    requirex = requirex,
}))
assert(relative_chunk() == "relative.child", "relative caller sources should still be rewritten")

local parent = wrapped_require "requirex.fixture.parent"
assert(parent.child.name == "child", "relative child module should load")
assert(parent.shared.name == "shared", "relative parent module should load")

local first_counter = wrapped_require "requirex.fixture.counter"
local second_counter = wrapped_require "requirex.fixture.counter"
assert(first_counter == second_counter, "normal require should use package.loaded cache")

local hot_require = requirex.reload(raw_require, true)
local first_hot_counter = hot_require "requirex.fixture.counter"
local second_hot_counter = hot_require "requirex.fixture.counter"
assert(first_hot_counter ~= second_hot_counter, "hot require should reload the target module")

require = raw_require

print("requirex test ok")
