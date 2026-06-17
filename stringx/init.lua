---@class lib.stringx.keymap.config
---@field name_to_code table<string, integer>?
---@field code_to_name table<integer, string>?

---@class lib.stringx.text_width_profile
---@field lower_scale number?
---@field upper_scale number?
---@field digit_scale number?
---@field normal_scale number?
---@field two_byte_scale number?
---@field three_byte_scale number?
---@field four_byte_scale number?
---@field space_scale number?
---@field height_scale number?

---@class lib.stringx.text_layout.config
---@field width_profile lib.stringx.text_width_profile?
---@field rich_text_matcher fun(text:string, index:integer):string?

---@class lib.stringx.config
---@field keymap lib.stringx.keymap.config?
---@field text_layout lib.stringx.text_layout.config?

---@class lib.stringx : stringlib
local g = string

local keymap = require "stringx.keymap"
local text_layout = require "stringx.text_layout"

---@param config lib.stringx.config?
function g.configure(config)
    assert(config == nil or type(config) == "table", "config must be a table or nil")
    config = config or {}
    keymap.configure(config.keymap)
    text_layout.configure(config.text_layout)
end

---@param config lib.stringx.keymap.config?
function g.configure_keymap(config)
    assert(config == nil or type(config) == "table", "keymap config must be a table or nil")
    keymap.configure(config)
end

---@param config lib.stringx.text_layout.config?
function g.configure_text_layout(config)
    assert(config == nil or type(config) == "table", "text layout config must be a table or nil")
    text_layout.configure(config)
end

---Replace by Lua pattern.
---@param str string
---@param pattern string
---@param replacement string
---@return string
---@return number
g.replace = function(str, pattern, replacement)
    return g.gsub(str, pattern, replacement)
end

---Return key code or first byte.
---@param str string
---@return integer
g.ord = function(str)
    assert(type(str) == "string" and str ~= "", "str must be a non-empty string")
    local code = keymap.code_for(str)
    if code then
        return code
    end
    return g.byte(str)
end

---Return display name or character.
---@param ascii integer
---@return string
g.chr = function(ascii)
    local name = keymap.name_for(ascii)
    if name then
        return name
    end
    return g.char(ascii)
end

---Return UTF-8 byte length at index.
---@param inputstr string
---@param index? integer
---@return integer
g.byte_length = function(inputstr, index)
    return text_layout.byte_length(inputstr, index)
end

---Return estimated text pixel width.
---@param inputstr string
---@return number
g.pixel_width = function(inputstr)
    return text_layout.pixel_width(inputstr)
end

---Count Lua pattern occurrences.
---@param str string
---@param pattern string
---@return number
g.count = function(str, pattern)
    assert(pattern ~= "", "pattern must be a non-empty string")
    return select(2, g.gsub(str, pattern, ""))
end

---Count plain text occurrences.
---@param str string
---@param text string
---@return number
g.count_plain = function(str, text)
    assert(text ~= "", "text must be a non-empty string")
    local count = 0
    local position = 1
    while true do
        local start_pos, end_pos = g.find(str, text, position, true)
        if not start_pos then
            return count
        end
        count = count + 1
        position = end_pos + 1
    end
end

---Check whether plain text exists.
---@param str string
---@param key string
---@return boolean
g.exists = function(str, key)
    local lo = g.find(str, key, 1, true)
    return lo ~= nil
end

---Trim surrounding whitespace.
---@param str string
---@return string
g.strip = function(str)
    if str == nil then
        return ""
    end
    return g.match(str, "^%s*(.-)%s*$")
end

---Wrap text and estimate rendered size.
---@param text string
---@param font_size number
---@param width_limit? number
---@return string
---@return number
---@return number
g.adapt = function(text, font_size, width_limit)
    return text_layout.adapt(text, font_size, width_limit)
end

---Split by plain delimiter.
---@param input string
---@param delimiter string
---@return string[]
g.split = function(input, delimiter)
    assert(delimiter ~= "", "delimiter must be a non-empty string")
    input = tostring(input)

    local position = 1
    local result = {}

    while true do
        local start_pos, end_pos = g.find(input, delimiter, position, true)
        if not start_pos then
            result[#result + 1] = g.sub(input, position)
            return result
        end

        result[#result + 1] = g.sub(input, position, start_pos - 1)
        position = end_pos + 1
    end
end

---Check whether a string contains digits only.
---@param s string
---@return boolean
g.isdigit = function(s)
    if type(s) ~= "string" or s == "" then
        return false
    end
    for i = 1, g.len(s) do
        local st = g.sub(s, i, i)
        if st < "0" or st > "9" then
            return false
        end
    end
    return true
end

---Keep only decimal digits and normalize leading zeros.
---@param s string
---@return string
g.tointeger = function(s)
    s = tostring(s or "")
    local digits = {}

    for i = 1, g.len(s) do
        local char = g.sub(s, i, i)
        if char >= "0" and char <= "9" then
            digits[#digits + 1] = char
        end
    end

    local result = table.concat(digits)
    if result == "" then
        return ""
    end

    result = result:match("^0*(%d+)$") or ""
    if result == "" then
        return "0"
    end
    return result
end

---Format a number with compact decimal places.
---@param num number
---@return string
g.simple_number = function(num)
    local function cal(value)
        for i = -1, 2 do
            if value >= 0.1 ^ i then
                return tonumber(g.format("%." .. i + 1 .. "f", value))
            end
        end
        return tonumber(g.format("%.2f", value))
    end

    num = cal(num)
    for i = 0, 2 do
        local text = g.format("%." .. i .. "f", num)
        if tonumber(text) == num then
            return text
        end
    end

    return num .. ""
end

---Convert integer to Chinese numerals for 0..999.
---@param num number
---@return string
g.i2ch = function(num)
    if type(num) ~= "number" or num % 1 ~= 0 or num < 0 then
        return tostring(num)
    end

    if num == 2 then
        return "两"
    end

    local map = {
        [0] = "零",
        [1] = "一",
        [2] = "二",
        [3] = "三",
        [4] = "四",
        [5] = "五",
        [6] = "六",
        [7] = "七",
        [8] = "八",
        [9] = "九",
        [10] = "十",
    }

    if num <= 10 then
        return map[num]
    end
    if num < 20 then
        return "十" .. map[num % 10]
    end
    if num < 100 then
        local ones = num % 10
        return map[math.floor(num / 10)] .. "十" .. (ones == 0 and "" or map[ones])
    end
    if num <= 999 then
        local text = map[math.floor(num / 100)] .. "百"
        num = num % 100
        if num > 0 then
            if num >= 10 then
                text = text .. map[math.floor(num / 10)] .. "十"
            else
                text = text .. "零"
            end
            num = num % 10
        end
        if num > 0 then
            text = text .. map[num]
        end
        return text
    end

    return num .. ""
end

---Find all Lua pattern start positions.
---@param str string
---@param pattern string
---@return integer[]
g.findall = function(str, pattern)
    assert(pattern ~= "", "pattern must be a non-empty string")
    local result = {}
    local position = 1

    while position <= g.len(str) do
        local start_pos, end_pos = g.find(str, pattern, position)
        if start_pos == nil then
            break
        end
        if end_pos < start_pos then
            error("pattern must not match an empty string", 2)
        end

        result[#result + 1] = start_pos
        position = end_pos + 1
    end

    return result
end

---Find all plain text start positions.
---@param str string
---@param text string
---@return integer[]
g.findall_plain = function(str, text)
    assert(text ~= "", "text must be a non-empty string")
    local result = {}
    local position = 1
    while true do
        local start_pos, end_pos = g.find(str, text, position, true)
        if not start_pos then
            return result
        end
        result[#result + 1] = start_pos
        position = end_pos + 1
    end
end

---Split rich color spans and non-color spans.
---@param str string
---@param func_co fun(sub: string)
---@param func_no fun(sub: string)
g.split_color = function(str, func_co, func_no)
    local function find_color(text, mask_s, mask_e)
        if text == nil or g.len(text) == 0 then
            return nil, nil
        end

        local starts = g.findall_plain(text, "|c")
        local ends = g.findall_plain(text, "|r")
        if #starts == 0 or #ends == 0 then
            return nil, nil
        end

        if mask_s ~= nil and mask_e ~= nil then
            local filtered_starts = {}
            local filtered_ends = {}
            for _, pos in ipairs(starts) do
                if pos < mask_s or pos > mask_e then
                    filtered_starts[#filtered_starts + 1] = pos
                end
            end
            for _, pos in ipairs(ends) do
                if pos < mask_s or pos > mask_e then
                    filtered_ends[#filtered_ends + 1] = pos
                end
            end
            starts = filtered_starts
            ends = filtered_ends
        end

        if #starts == 0 or #ends == 0 then
            return nil, nil
        end

        local end_pos = ends[1]
        local start_pos
        for _, pos in ipairs(starts) do
            if pos < end_pos then
                start_pos = pos
            else
                break
            end
        end

        if start_pos == nil then
            return nil, nil
        end

        local range_start = start_pos
        local range_end = end_pos + 1
        if mask_s ~= nil and mask_e ~= nil and (range_start >= mask_s or range_end <= mask_e) then
            return nil, nil
        end

        local outer_start, outer_end = find_color(text, start_pos, end_pos + 1)
        if outer_start == nil then
            return range_start, range_end
        end
        return outer_start, outer_end
    end

    local function do_split(text)
        local start_pos, end_pos = find_color(text)
        if start_pos == nil then
            func_no(text)
            return
        end

        func_no(g.sub(text, 1, start_pos - 1))
        func_co(g.sub(text, start_pos, end_pos))
        do_split(g.sub(text, end_pos + 1))
    end

    do_split(str)
end

---Find plain text from the right.
---@param s string
---@param pt string
---@return integer?
g.rfind = function(s, pt)
    assert(pt ~= "", "pt must be a non-empty string")
    local result
    local position = 1
    while true do
        local start_pos, end_pos = g.find(s, pt, position, true)
        if not start_pos then
            return result
        end
        result = start_pos
        position = end_pos + 1
    end
end

---Join strings by separator.
---@param string_list string[]
---@param split string
---@return string
g.join = function(string_list, split)
    local parts = {}
    for index, str in ipairs(string_list) do
        parts[index] = str
    end
    return table.concat(parts, split)
end

---Check prefix.
---@param s string
---@param prefix string
---@return boolean
g.startswith = function(s, prefix)
    return g.sub(s, 1, g.len(prefix)) == prefix
end

---Check suffix.
---@param s string
---@param suffix string
---@return boolean
g.endswith = function(s, suffix)
    return g.sub(s, g.len(s) - g.len(suffix) + 1) == suffix
end

---@param text string
---@param render_fn fun(key:string):string?
---@return string rendered
g.render_placeholders = function(text, render_fn)
    local parts = {}
    local last_index = 1

    while true do
        local start_pos, end_pos, key = text:find("{([^{}]-)}", last_index)
        if not start_pos then
            parts[#parts + 1] = text:sub(last_index)
            break
        end
        if start_pos > last_index then
            parts[#parts + 1] = text:sub(last_index, start_pos - 1)
        end

        local replaced = render_fn(key)
        parts[#parts + 1] = replaced or text:sub(start_pos, end_pos)
        last_index = end_pos + 1
    end

    return table.concat(parts)
end

return g
