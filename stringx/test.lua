local source = debug.getinfo(1, "S").source
local stringx_dir = source:sub(1, 1) == "@" and source:sub(2) or source
stringx_dir = stringx_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = stringx_dir:match("^(.*)[/\\][^/\\]+$") or stringx_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local stringx = require "stringx"

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_eq") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

local function assert_list(actual, expected, message)
    assert_eq(#actual, #expected, (message or "assert_list") .. " length")
    for i, value in ipairs(expected) do
        assert_eq(actual[i], value, (message or "assert_list") .. " item " .. i)
    end
end

stringx.configure()

local ok = pcall(stringx.configure, 1)
assert(not ok, "configure should reject non-table config")
ok = pcall(stringx.configure_keymap, 1)
assert(not ok, "configure_keymap should reject non-table config")
ok = pcall(stringx.configure_text_layout, 1)
assert(not ok, "configure_text_layout should reject non-table config")

assert_eq(stringx.replace("a-b-a", "a", "x"), "x-b-x", "replace should use Lua patterns")
assert_eq(stringx.count("banana", "a"), 3, "count should use Lua patterns")
assert_eq(stringx.count_plain("aaaa", "aa"), 2, "count_plain should not overlap")
assert_eq(stringx.exists("hello", "ell"), true, "exists should find plain text")
assert_eq(stringx.strip(" \t hello \n"), "hello", "strip should trim whitespace")

assert_list(stringx.split("a..b.", "."), { "a", "", "b", "" }, "split should keep empty parts")
assert_eq(stringx.isdigit("123"), true, "isdigit should accept digits")
assert_eq(stringx.isdigit("12a"), false, "isdigit should reject non-digits")
assert_eq(stringx.tointeger("a0012b03"), "1203", "tointeger should keep digits")
assert_eq(stringx.tointeger("000"), "0", "tointeger should normalize zero")
assert_eq(stringx.tointeger("000123456789012345678901234567890"), "123456789012345678901234567890", "tointeger should not lose precision")

assert_eq(stringx.simple_number(12.345), "12", "simple_number should compact large decimals")
assert_eq(stringx.simple_number(0.044), "0.044", "simple_number should keep small decimals")
assert_eq(stringx.i2ch(0), "零", "i2ch zero")
assert_eq(stringx.i2ch(2), "两", "i2ch two uses liang")
assert_eq(stringx.i2ch(101), "一百零一", "i2ch hundreds with zero")
assert_eq(stringx.i2ch(110), "一百一十", "i2ch hundreds with tens")
assert_eq(stringx.i2ch(1000), "1000", "i2ch should only convert supported range")

assert_list(stringx.findall("banana", "a"), { 2, 4, 6 }, "findall should return pattern positions")
assert_list(stringx.findall_plain("aaaa", "aa"), { 1, 3 }, "findall_plain should not overlap")
assert_eq(stringx.rfind("banana", "a"), 6, "rfind should return last plain position")
assert_eq(stringx.rfind("banana", "x"), nil, "rfind should return nil when missing")
assert_eq(stringx.join({ "a", "b", "c" }, ","), "a,b,c", "join should concatenate parts")
assert_eq(stringx.startswith("hello", "he"), true, "startswith")
assert_eq(stringx.endswith("hello", "lo"), true, "endswith")

assert_eq(stringx.render_placeholders("a {x} {missing}", function(key)
    if key == "x" then
        return "1"
    end
    return nil
end), "a 1 {missing}", "render_placeholders should keep unknown placeholders")

assert_eq(stringx.ord("A"), 65, "ord should use first byte")
assert_eq(stringx.ord("ctrl"), 17, "ord should use keymap names")
assert_eq(stringx.chr(65), "A", "chr should use keymap display names")
stringx.configure_keymap({
    name_to_code = {
        jump = 32,
    },
    code_to_name = {
        [32] = "Jump",
    },
})
assert_eq(stringx.ord("jump"), 32, "configure_keymap should add names")
assert_eq(stringx.chr(32), "Jump", "configure_keymap should add display names")
stringx.configure()
assert_eq(stringx.ord("jump"), string.byte("j"), "configure should reset keymap defaults")
assert_eq(stringx.chr(32), " ", "configure should reset display names")

stringx.configure_text_layout({
    width_profile = {
        lower_scale = 1,
        upper_scale = 2,
        digit_scale = 3,
        normal_scale = 4,
        two_byte_scale = 5,
        three_byte_scale = 6,
        four_byte_scale = 7,
        space_scale = 8,
        height_scale = 2,
    },
    rich_text_matcher = function(text, index)
        if text:sub(index, index + 2) == "<c>" then
            return "<c>"
        end
        return nil
    end,
})
assert_eq(stringx.pixel_width("aA1 x中"), 1 + 2 + 3 + 8 + 1 + 6, "pixel_width should use configured profile")
local adapted, width, height = stringx.adapt("ab<c>cd", 10, 25)
assert_eq(adapted, "ab<c>\ncd", "adapt should ignore rich text width and wrap visible text")
assert_eq(width, 20, "adapt width")
assert_eq(height, 40, "adapt height")
stringx.configure()

ok = pcall(function()
    stringx.configure_text_layout({
        rich_text_matcher = function()
            return true
        end,
    })
    stringx.adapt("abc", 10)
end)
assert(not ok, "rich_text_matcher should reject non-string matches")
stringx.configure()

local colored = {}
stringx.split_color("a|cff0000red|rb", function(sub)
    colored[#colored + 1] = "C:" .. sub
end, function(sub)
    colored[#colored + 1] = "N:" .. sub
end)
assert_list(colored, { "N:a", "C:|cff0000red|r", "N:b" }, "split_color should split color spans")

ok = pcall(stringx.count, "abc", "")
assert(not ok, "count should reject empty patterns")
ok = pcall(stringx.findall, "abc", "")
assert(not ok, "findall should reject empty patterns")
ok = pcall(stringx.findall, "abc", "a*")
assert(not ok, "findall should reject patterns that match empty strings")
ok = pcall(stringx.split, "abc", "")
assert(not ok, "split should reject empty delimiters")
ok = pcall(stringx.count_plain, "abc", "")
assert(not ok, "count_plain should reject empty text")
ok = pcall(stringx.rfind, "abc", "")
assert(not ok, "rfind should reject empty text")

print("stringx test ok")
