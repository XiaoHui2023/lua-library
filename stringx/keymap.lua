---@class lib.stringx.keymap.config
---@field name_to_code table<string, 字段说明
---@field code_to_name table<integer, 字段说明

---@class lib.stringx.keymap
local M = {}

---@type table<string, integer>
local name_to_code = {}

---@type table<integer, string>
local code_to_name = {}

---@type table<string, integer>
local default_special_names = {
    ctrl = 17,
    alt = 18,
    shift = 16,
    space = 32,
    enter = 13,
    esc = 27,
    tab = 9,
    backspace = 8,
    delete = 127,
    left = 37,
    up = 38,
    right = 39,
    down = 40,
    tilde = 126,
}

---@type table<integer, string>
local default_display_names = {
    [48] = "0",
    [49] = "1",
    [50] = "2",
    [51] = "3",
    [52] = "4",
    [53] = "5",
    [54] = "6",
    [55] = "7",
    [56] = "8",
    [57] = "9",
    [65] = "A",
    [66] = "B",
    [67] = "C",
    [68] = "D",
    [69] = "E",
    [70] = "F",
    [71] = "G",
    [72] = "H",
    [73] = "I",
    [74] = "J",
    [75] = "K",
    [76] = "L",
    [77] = "M",
    [78] = "N",
    [79] = "O",
    [80] = "P",
    [81] = "Q",
    [82] = "R",
    [83] = "S",
    [84] = "T",
    [85] = "U",
    [86] = "V",
    [87] = "W",
    [88] = "X",
    [89] = "Y",
    [90] = "Z",
}

---@param source table
local function clear(source)
    for key in pairs(source) do
        source[key] = nil
    end
end

---@param name string
---@return string
local function normalize_name(name)
    return string.lower(name)
end

---@param name string
---@param code integer
function M.add_name(name, code)
    assert(type(name) == "string" and name ~= "", "key name must be a non-empty string")
    assert(type(code) == "number" and code % 1 == 0, "key code must be an integer")
    name_to_code[normalize_name(name)] = code
end

---@param code integer
---@param name string
function M.add_display_name(code, name)
    assert(type(code) == "number" and code % 1 == 0, "key code must be an integer")
    assert(type(name) == "string" and name ~= "", "display name must be a non-empty string")
    code_to_name[code] = name
end

---@param config lib.stringx.keymap.config? 参数说明
function M.configure(config)
    clear(name_to_code)
    clear(code_to_name)

    for name, code in pairs(default_special_names) do
        M.add_name(name, code)
    end
    for code, name in pairs(default_display_names) do
        M.add_display_name(code, name)
    end

    if not config then
        return
    end

    if config.name_to_code then
        for name, code in pairs(config.name_to_code) do
            M.add_name(name, code)
        end
    end
    if config.code_to_name then
        for code, name in pairs(config.code_to_name) do
            M.add_display_name(code, name)
        end
    end
end

---@param value string
---@return integer? 返回值
function M.code_for(value)
    return name_to_code[normalize_name(value)]
end

---@param code integer
---@return string? 返回值
function M.name_for(code)
    return code_to_name[code]
end

M.configure()

return M
