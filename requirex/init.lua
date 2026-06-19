---@class lib.requirex
local M = {}

local root ---@type string?
local requirex_source_suffix = "requirex/init.lua"

local function normalize_path(path)
    path = path:gsub("\\", "/")
    while path:find("//", 1, true) do
        path = path:gsub("//", "/")
    end
    return path
end

local function trim_trailing_slash(path)
    while #path > 0 and path:sub(-1) == "/" do
        path = path:sub(1, -2)
    end
    return path
end

local function dirname(path)
    path = trim_trailing_slash(normalize_path(path))
    return path:match("^(.*)/[^/]*$") or ""
end

local function starts_with(value, prefix)
    return value:sub(1, #prefix) == prefix
end

local function ends_with(value, suffix)
    return value:sub(-#suffix) == suffix
end

local function is_requirex_source(source)
    return source == requirex_source_suffix or ends_with(source, "/" .. requirex_source_suffix)
end

local function is_relative_module(path)
    return type(path) == "string" and path:sub(1, 1) == "."
end

local function is_absolute_path(path)
    return path:sub(1, 1) == "/" or path:match("^%a:/") ~= nil
end

local function source_relative_to_root(source, root_path)
    root_path = trim_trailing_slash(root_path)
    if root_path == "" then
        if is_absolute_path(source) then
            return nil
        end
        return source
    end
    if source == root_path then
        return ""
    end
    if starts_with(source, root_path .. "/") then
        return source:sub(#root_path + 2)
    end
    return nil
end

local function find_root_by_postfix(source, postfix)
    if source == postfix then
        return ""
    end

    local suffix = "/" .. postfix
    if ends_with(source, suffix) then
        return source:sub(1, #source - #postfix)
    end

    return nil
end

local function caller_relative_base(level)
    if root == nil then
        return nil
    end

    local normalized_root = normalize_path(root)
    for stack_level = level, level + 12 do
        local info = debug.getinfo(stack_level, "S")
        if info == nil then
            return nil
        end

        if info.source ~= nil then
            local source = normalize_path(info.source:gsub("^@", ""))
            local relative_source = source_relative_to_root(source, normalized_root)
            if relative_source ~= nil then
                if not is_requirex_source(relative_source) then
                    return dirname(relative_source)
                end
            elseif source:sub(-4) == ".lua" and not is_requirex_source(source) then
                if is_absolute_path(source) then
                    return nil
                end

                return dirname(source)
            elseif is_absolute_path(source) and not is_requirex_source(source) then
                return nil
            end
        end
    end

    return nil
end

local function split_relative_module(path)
    local dot_count = 0
    while path:sub(dot_count + 1, dot_count + 1) == "." do
        dot_count = dot_count + 1
    end

    return dot_count - 1, path:sub(dot_count + 1)
end

local function join_module(base, suffix)
    local path = base
    if suffix ~= "" then
        if path ~= "" then
            path = path .. "/" .. suffix
        else
            path = suffix
        end
    end

    path = normalize_path(path):gsub("/", ".")
    while path:sub(1, 1) == "." do
        path = path:sub(2)
    end
    return path
end

local function resolve_relative(path, level)
    if not is_relative_module(path) then
        return path
    end

    local base = caller_relative_base(level)
    if base == nil then
        return path
    end

    local up_count, suffix = split_relative_module(path)
    for _ = 1, up_count do
        if base == "" then
            error("relative require '" .. path .. "' exceeds root", level)
        end

        base = dirname(base)
    end

    return join_module(base, suffix)
end

---初始化相对 require 使用的根目录。
---@param postfix string 调用者文件相对根目录的后缀路径
M.initial = function(postfix)
    assert(type(postfix) == "string", "postfix must be string")

    local info = debug.getinfo(2, "S")
    assert(info ~= nil and info.source ~= nil, "cannot get caller source")

    local source = normalize_path(info.source:gsub("^@", ""))
    postfix = normalize_path(postfix)

    local found_root = find_root_by_postfix(source, postfix)
    if found_root == nil then
        error("Not found '" .. postfix .. "' in '" .. source .. "'", 2)
    end

    root = found_root
end

---只解析模块路径，不加载模块。
---@param path string 待解析的模块路径
---@param level? integer 调用栈层级；省略时按公开入口解析
---@return string resolved 解析后的模块路径
M.resolve = function(path, level)
    assert(type(path) == "string", "path must be string")
    return resolve_relative(path, level or 3)
end

---包装 require，使 `.` 开头的路径按调用者文件解析。
---hot_reload 为 true 时，只清理解析后的目标模块缓存。
---@param method fun(path: string): any 加载函数，通常为原始 require
---@param hot_reload? boolean 是否在加载前清理目标模块缓存
---@return fun(path: string): any require_fn 包装后的加载函数
M.reload = function(method, hot_reload)
    assert(type(method) == "function", "method must be function")

    hot_reload = hot_reload or false

    return function(path)
        assert(type(path) == "string", "path must be string")

        local resolved = resolve_relative(path, 4)
        if hot_reload then
            package.loaded[resolved] = nil
        end

        return method(resolved)
    end
end

return M
