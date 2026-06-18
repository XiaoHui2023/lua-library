---@class lib.debugx
local g = {}

---@type lib.tablex
local tablex = require "lib.tablex"

---@class lib.debugx.backend
---@field debug? fun(...)
---@field info? fun(...)
---@field warn? fun(...)
---@field error? fun(msg: string)
---@field get_debug_mode? fun(): boolean

---@type lib.debugx.backend
local backend = {
    debug = function(...)
        print(...)
    end,
    info = function(...)
        print(...)
    end,
    warn = function(...)
        print(...)
    end,
    error = function(msg)
        error(msg, 2)
    end,
    get_debug_mode = function()
        return false
    end,
}

---@param next_backend lib.debugx.backend
g.set_backend = function(next_backend)
    assert(type(next_backend) == "table", "debugx backend must be a table")
    if next_backend.debug ~= nil then
        assert(type(next_backend.debug) == "function", "debugx backend.debug must be a function")
        backend.debug = next_backend.debug
    end
    if next_backend.info ~= nil then
        assert(type(next_backend.info) == "function", "debugx backend.info must be a function")
        backend.info = next_backend.info
    end
    if next_backend.warn ~= nil then
        assert(type(next_backend.warn) == "function", "debugx backend.warn must be a function")
        backend.warn = next_backend.warn
    end
    if next_backend.error ~= nil then
        assert(type(next_backend.error) == "function", "debugx backend.error must be a function")
        backend.error = next_backend.error
    end
    if next_backend.get_debug_mode ~= nil then
        assert(type(next_backend.get_debug_mode) == "function", "debugx backend.get_debug_mode must be a function")
        backend.get_debug_mode = next_backend.get_debug_mode
    end
end

local function traceback_message(message)
    if debug == nil or debug.traceback == nil then
        return tostring(message)
    end
    return debug.traceback(tostring(message), 3)
end

g.debug = function(...)
    if backend.get_debug_mode() then
        return backend.debug(...)
    end
end

g.info = function(...)
    return backend.info(...)
end

g.warn = function(...)
    return backend.warn(...)
end

---@param msg any
g.error = function(msg)
    return backend.error(traceback_message(msg))
end

---@return boolean
g.get_debug_mode = function()
    return backend.get_debug_mode()
end

local function primitive_to_string(value)
    local tp = type(value)
    if tp == "string" then
        return string.format("%q", value)
    elseif tp == "number" or tp == "boolean" or tp == "nil" then
        return tostring(value)
    end
    return string.format("%q", tostring(value))
end

local function append_dump(parts, value, stack)
    if type(value) ~= "table" then
        parts[#parts + 1] = primitive_to_string(value)
        return
    end

    if stack[value] then
        parts[#parts + 1] = string.format("%q", "<cycle:" .. tostring(value) .. ">")
        return
    end

    stack[value] = true
    parts[#parts + 1] = "{"

    local index = 1
    local first = true
    for key, item in tablex.sorted_pairs(value) do
        if not first then
            parts[#parts + 1] = ","
        end
        first = false

        if key == index then
            append_dump(parts, item, stack)
        else
            parts[#parts + 1] = "["
            append_dump(parts, key, stack)
            parts[#parts + 1] = "]="
            append_dump(parts, item, stack)
        end

        index = index + 1
    end

    parts[#parts + 1] = "}"
    stack[value] = nil
end

---Converts a value to a Lua-literal-like string.
---Functions, userdata, threads, and cyclic references are represented as strings.
---@param value any
---@return string text
g.dump = function(value)
    local parts = {}
    append_dump(parts, value, {})
    return table.concat(parts)
end

---Runs `return <str>` and returns the result.
---This is intended for simple debug strings produced by `g.dump`; do not pass untrusted content.
---@param str string Lua expression string
---@return any value
g.load = function(str)
    assert(type(str) == "string", "str must be string")

    local env = {}
    local func = load("return " .. str, "debugx.load", "t", env)
    if func == nil then
        return {}
    end

    local ok, result = pcall(func)
    if not ok then
        return {}
    end

    return result
end

local function print_value(value, prefix, indent, cache)
    if type(value) ~= "table" then
        backend.debug(prefix .. primitive_to_string(value))
        return
    end

    if cache[value] then
        backend.debug(prefix .. "*" .. tostring(value))
        return
    end

    cache[value] = true
    backend.debug(prefix .. tostring(value) .. " {")

    local child_indent = indent .. "  "
    for key, item in tablex.sorted_pairs(value) do
        local key_text = primitive_to_string(key)
        print_value(item, child_indent .. "[" .. key_text .. "] => ", child_indent, cache)
    end

    backend.debug(indent .. "}")
    cache[value] = nil
end

---Recursively prints one or more values. Tables are expanded in stable key order.
---@param ... any
g.print = function(...)
    for i = 1, select("#", ...) do
        print_value(select(i, ...), "", "", {})
    end
end

return g
