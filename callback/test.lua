local source = debug.getinfo(1, "S").source
local callback_dir = source:sub(1, 1) == "@" and source:sub(2) or source
callback_dir = callback_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = callback_dir:match("^(.*)[/\\][^/\\]+$") or callback_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local callback = require "callback"

local function assert_same(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_same") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

---@class test.OnDamage
---@field source any 测试伤害来源
---@field target any 测试伤害目标
---@field amount number 测试伤害数值
local OnDamage = callback.api({ name = "OnDamage" })

local called = 0
OnDamage(function(api)
    called = called + 1
    api:set("amount", api.amount + 1)
end)

OnDamage:register(function(api)
    called = called + 1
    api.handled = true
end)

local payload = OnDamage:emit({ source = "a", target = "b", amount = 2 })
assert_same(called, 2, "api should call all registered implementations")
assert_same(payload.amount, 3, "api implementation should be able to mutate the instance")
assert_same(payload.handled, true, "api implementation should share the same instance")
assert_same(payload.values.amount, 3, "set should keep values in sync")
assert_same(payload.values.handled, true, "direct assignment should keep values in sync")
assert_same(payload:trigger(), payload, "instance trigger should return itself")
assert_same(called, 4, "instance trigger should emit the same instance")
local reserved_ok = pcall(function()
    payload.api = nil
end)
assert_same(reserved_ok, false, "instance should reject reserved field assignment")

local unsubscribe = OnDamage(function()
    called = called + 1
end)
unsubscribe()
OnDamage({ amount = 1 })
assert_same(called, 6, "unsubscribe should remove handler")

local ShadowApi = callback.api({ name = "ShadowApi" })
local shadow_seen = nil
ShadowApi(function(api)
    shadow_seen = api:get("api")
end)
local shadow_ok = pcall(function()
    ShadowApi({ api = ShadowApi })
end)
assert_same(shadow_ok, true, "plain payload api field should not be treated as an instance")
assert_same(shadow_seen, ShadowApi, "plain payload api field should still be available through values")

local errors = 0
callback.set_event_error_handler(function()
    errors = errors + 1
end)

local ContinueAfterError = callback.api({ name = "ContinueAfterError" })
local after_error = 0
ContinueAfterError(function()
    error("continue error")
end)
ContinueAfterError(function()
    after_error = after_error + 1
end)
ContinueAfterError()
assert_same(errors, 1, "non-strict mode should report handler errors")
assert_same(after_error, 1, "non-strict mode should continue after handler errors")

local once_args = { name = "OnceArgs" }
local Once = callback.once_event(once_args)
assert_same(once_args.mode, nil, "once_event should not mutate args")
local once_count = 0
Once.add(function()
    once_count = once_count + 1
end)
Once()
Once()
assert_same(once_count, 1, "once_event should run handlers once")

local replay = callback.event({ name = "Replay", replay = true })
replay("first", nil, "third")
local replay_a
local replay_b
local replay_c
replay.add(function(a, b, c)
    replay_a = a
    replay_b = b
    replay_c = c
end)
assert_same(replay_a, "first", "replay should preserve first arg")
assert_same(replay_b, nil, "replay should preserve nil middle arg")
assert_same(replay_c, "third", "replay should preserve args after nil")

callback.set_strict(true)
local StrictReplay = callback.event({ name = "StrictReplay", replay = true })
StrictReplay()
local replay_ok, replay_err = pcall(function()
    StrictReplay.add(function()
        error("strict replay error")
    end)
end)
assert_same(replay_ok, false, "strict mode should rethrow replay errors")
assert(replay_err:find("strict replay error", 1, true), "strict mode should rethrow the original replay error")

local StrictError = callback.api({ name = "StrictError" })
local strict_after_error = 0
StrictError(function()
    error("strict error")
end)
StrictError(function()
    strict_after_error = strict_after_error + 1
end)
local ok, err = pcall(function()
    StrictError()
end)
assert_same(ok, false, "strict mode should rethrow handler errors")
assert(err:find("strict error", 1, true), "strict mode should rethrow the original error")
assert_same(strict_after_error, 1, "strict mode should still leave the event in a clean state")
callback.set_strict(false)
callback.set_event_error_handler(nil)

print("callback test ok")
