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

---@class lib.stringx.text_layout.data
---@field data string
---@field width number
---@field wrap boolean

---@class lib.stringx.text_layout
local M = {}

local color_loaded = false
local color_lib = nil

---@type lib.stringx.text_width_profile
local default_width_profile = {
    lower_scale = 17 / 13,
    upper_scale = 18 / 13,
    digit_scale = 6.5 / 13,
    normal_scale = 7 / 13,
    two_byte_scale = 26 / 13,
    three_byte_scale = 26 / 13,
    four_byte_scale = 1,
    height_scale = 178 / 5 / 13,
}

---@type lib.stringx.text_width_profile
local width_profile = {}

---@type fun(text:string, index:integer):string?
local rich_text_matcher

---@return table?
local function get_color_lib()
    if not color_loaded then
        color_loaded = true
        local ok, color = pcall(require, "color")
        if ok and type(color) == "table" then
            color_lib = color
        end
    end
    return color_lib
end

---@param profile lib.stringx.text_width_profile?
local function apply_width_profile(profile)
    for key, value in pairs(default_width_profile) do
        width_profile[key] = value
    end
    width_profile.space_scale = width_profile.two_byte_scale / 2

    if not profile then
        return
    end

    for key, value in pairs(profile) do
        assert(type(value) == "number", key .. " must be a number")
        width_profile[key] = value
    end
end

---@param text string
---@param index integer
---@return string?
local function default_rich_text_matcher(text, index)
    local color = get_color_lib()
    if not color or type(color.PATTERNS) ~= "table" then
        return nil
    end

    local rest = string.sub(text, index)
    for _, pattern in ipairs(color.PATTERNS) do
        if string.find(rest, pattern) == 1 then
            return string.match(rest, pattern)
        end
    end
    return nil
end

---@param value any
---@return string?
local function normalize_text(value)
    if value == nil then
        return nil
    end
    if type(value) == "number" then
        return value .. ""
    end
    if type(value) ~= "string" then
        return nil
    end
    return value
end

---@param config lib.stringx.text_layout.config?
function M.configure(config)
    config = config or {}
    apply_width_profile(config.width_profile)

    if config.rich_text_matcher ~= nil then
        assert(type(config.rich_text_matcher) == "function", "rich_text_matcher must be a function")
        rich_text_matcher = config.rich_text_matcher
    else
        rich_text_matcher = default_rich_text_matcher
    end
end

---@param inputstr any
---@param index? integer
---@return integer
function M.byte_length(inputstr, index)
    local text = normalize_text(inputstr)
    if not text or text == "" then
        return 0
    end

    index = index or 1
    if index < 1 or index > #text then
        return 0
    end

    local byte = string.byte(text, index)
    if not byte then
        return 0
    end
    if byte > 239 then
        return 4
    elseif byte > 223 then
        return 3
    elseif byte > 128 then
        return 2
    end
    return 1
end

---@param inputstr any
---@return number
function M.pixel_width(inputstr)
    local text = normalize_text(inputstr)
    if not text or text == "" then
        return 0
    end

    local length = string.len(text)
    local width = 0
    local index = 1

    while index <= length do
        local char_length = M.byte_length(text, index)
        if char_length == 0 then
            break
        end

        if char_length == 1 then
            local byte = string.byte(text, index)
            if byte >= string.byte("a") and byte <= string.byte("z") then
                width = width + width_profile.lower_scale
            elseif byte >= string.byte("A") and byte <= string.byte("Z") then
                width = width + width_profile.upper_scale
            elseif byte >= string.byte("0") and byte <= string.byte("9") then
                width = width + width_profile.digit_scale
            elseif byte == string.byte(" ") then
                width = width + width_profile.space_scale
            else
                width = width + width_profile.normal_scale
            end
        elseif char_length == 2 then
            width = width + width_profile.two_byte_scale
        elseif char_length == 3 then
            width = width + width_profile.three_byte_scale
        else
            width = width + width_profile.four_byte_scale
        end

        index = index + char_length
    end

    return width
end

---@return lib.stringx.text_layout.data
local function new_line()
    return {
        data = "\n",
        width = 0,
        wrap = true,
    }
end

---@param text string
---@param font_size number
---@return lib.stringx.text_layout.data[]
local function to_data(text, font_size)
    local result = {}
    local index = 1
    local length = #text

    while index <= length do
        local matched = rich_text_matcher(text, index)
        assert(matched == nil or type(matched) == "string", "rich_text_matcher must return a string or nil")
        if matched and matched ~= "" then
            result[#result + 1] = {
                data = matched,
                width = 0,
                wrap = false,
            }
            index = index + #matched
        else
            local char_length = M.byte_length(text, index)
            if char_length == 0 then
                break
            end

            local char = string.sub(text, index, index + char_length - 1)
            if char == "\n" then
                result[#result + 1] = new_line()
            else
                result[#result + 1] = {
                    data = char,
                    width = M.pixel_width(char) * font_size,
                    wrap = false,
                }
            end
            index = index + char_length
        end
    end

    return result
end

---@param text any
---@param font_size number
---@param width_limit? number
---@return string
---@return number
---@return number
function M.adapt(text, font_size, width_limit)
    text = normalize_text(text) or ""
    assert(type(font_size) == "number", "font_size must be a number")
    if width_limit ~= nil then
        assert(type(width_limit) == "number", "width_limit must be a number")
    end

    local in_datas = to_data(text, font_size)
    local out_datas = {}
    local max_width = 0
    local line_number = 1
    local current_width = 0

    local function widen()
        if current_width > max_width then
            max_width = current_width
        end
    end

    local function line_feed()
        widen()
        line_number = line_number + 1
        current_width = 0
    end

    for _, data in ipairs(in_datas) do
        if data.wrap then
            out_datas[#out_datas + 1] = data
            line_feed()
        else
            if width_limit and current_width > 0 and current_width + data.width > width_limit then
                out_datas[#out_datas + 1] = new_line()
                line_feed()
            end

            out_datas[#out_datas + 1] = data
            current_width = current_width + data.width
        end
    end

    widen()

    local parts = {}
    for index, data in ipairs(out_datas) do
        parts[index] = data.data
    end

    return table.concat(parts), max_width, font_size * line_number * width_profile.height_scale
end

M.configure()

return M
