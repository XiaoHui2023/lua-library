---@class lib.metatablex
local M = {}

local debug_getmetatable = debug and debug.getmetatable

local function get_plain_metatable(t)
    local mt = debug_getmetatable and debug_getmetatable(t) or getmetatable(t)
    if mt ~= nil and type(mt) ~= "table" then
        error("metatable is protected and cannot be copied", 3)
    end
    if mt ~= nil and mt.__metatable ~= nil then
        error("metatable is protected and cannot be copied", 3)
    end
    if mt ~= nil then
        local ok = pcall(setmetatable, t, mt)
        if not ok then
            error("metatable is protected and cannot be copied", 3)
        end
    end
    return mt
end

local function copy_metatable(mt)
    local copied = {}
    if mt ~= nil then
        for key, value in pairs(mt) do
            copied[key] = value
        end
    end
    return copied
end

---合并并设置 metatable。
---
---会保留目标对象原 metatable 中已有的字段，并用传入字段覆盖同名字段。
---不会原地修改旧 metatable，因此不会影响共享同一个 metatable 的其他对象。
---@generic T: table
---@param t T 目标表
---@param metatable table 要合并到 metatable 的字段
---@return T t 目标表
M.with_metatable = function(t, metatable)
    assert(type(t) == "table", "t must be table")
    assert(type(metatable) == "table", "metatable must be table")

    local mt = copy_metatable(get_plain_metatable(t))
    for k, v in pairs(metatable) do
        mt[k] = v
    end

    return setmetatable(t, mt)
end

local function call_newindex(newindex, self, key, value)
    if type(newindex) == "function" then
        newindex(self, key, value)
    elseif type(newindex) == "table" then
        newindex[key] = value
    else
        rawset(self, key, value)
    end
end

---
---不传 key 时，禁止通过普通赋值新增字段。
---传入 key 时，只禁止通过 __newindex 写入该 key。
---
---注意：Lua 的 __newindex 不能拦截已有字段的直接赋值，因此这个函数不是强只读。
---@generic T: table
---@param t T 目标表
---@param key? any 指定锁定的字段；省略时禁止新增字段
---@return T t 目标表
M.lock_new_fields = function(t, key)
    assert(type(t) == "table", "t must be table")

    local mt = get_plain_metatable(t) or {}
    local newindex = mt.__newindex

    if key ~= nil then
        return M.with_metatable(t, {
            __newindex = function(self, k, v)
                if k == key then
                    error("key:'" .. tostring(k) .. "' is locked", 2)
                end
                call_newindex(newindex, self, k, v)
            end
        })
    end

    return M.with_metatable(t, {
        __newindex = function(_, k)
            error(string.format("%s is locked, cannot set new key '%s'", tostring(t), tostring(k)), 2)
        end
    })
end

---readonly 是 lock_new_fields 的兼容别名。
M.readonly = M.lock_new_fields

---创建强只读代理。
---
---原表本身仍然可以被持有它的代码修改，因此这个函数适合对外暴露只读视图。
---@generic T: table
---@param t T 目标表
---@return T proxy 只读代理
M.readonly_proxy = function(t)
    assert(type(t) == "table", "t must be table")

    local proxy = {}
    return setmetatable(proxy, {
        __index = t,
        __newindex = function(_, k)
            error(string.format("%s is readonly, cannot set key '%s'", tostring(t), tostring(k)), 2)
        end,
        __len = function()
            return #t
        end,
        __pairs = function()
            return pairs(t)
        end,
        __ipairs = function()
            return ipairs(t)
        end,
        __tostring = function()
            return tostring(t)
        end,
        __metatable = false,
    })
end

---设置 __call。
---
---调用目标表时会转发到 func，目标表自身不会作为第一个参数传入。
---@generic T: table
---@param t T 目标表
---@param func fun(...): any 被调用的函数
---@return T t 目标表
M.callable = function(t, func)
    assert(type(t) == "table", "t must be table")
    assert(type(func) == "function", "func must be function")
    return M.with_metatable(t, {
        __call = function(_, ...)
            return func(...)
        end
    })
end

---设置 __call，并将目标表作为第一个参数传入。
---@generic T: table
---@param t T 目标表
---@param method fun(self: T, ...): any 被调用的方法
---@return T t 目标表
M.callable_method = function(t, method)
    assert(type(t) == "table", "t must be table")
    assert(type(method) == "function", "method must be function")
    return M.with_metatable(t, {
        __call = function(self, ...)
            return method(self, ...)
        end
    })
end

---设置 __tostring。
---@generic T: table
---@param t T 目标表
---@param func fun(self: T): string 字符串生成函数
---@return T t 目标表
M.with_tostring = function(t, func)
    assert(type(t) == "table", "t must be table")
    assert(type(func) == "function", "func must be function")
    return M.with_metatable(t, {
        __tostring = function(self)
            return func(self)
        end
    })
end

---用 string.format 的参数设置 __tostring。
---
---参数会在调用本函数时被捕获；如果显示内容依赖可变字段，请直接使用 with_tostring。
---@generic T: table
---@param t T 目标表
---@param ... any 传给 string.format 的参数，第一个参数应为格式字符串
---@return T t 目标表
M.with_tostring_format = function(t, ...)
    local args = { ... }
    return M.with_tostring(t, function()
        return string.format(table.unpack(args))
    end)
end

---设置 __index 代理。
---
---func 返回非 nil 时使用该结果；返回 nil 时回退到原 __index 或 rawget。
---@generic T: table
---@param t T 目标表
---@param func fun(self: T, key:any): any 索引代理函数
---@return T t 目标表
M.index_proxy = function(t, func)
    assert(type(t) == "table", "t must be table")
    assert(type(func) == "function", "func must be function")

    local mt = get_plain_metatable(t) or {}
    local index = mt.__index

    local fallback = function(self, key)
        if type(index) == "function" then
            return index(self, key)
        elseif type(index) == "table" then
            return index[key]
        end
        return rawget(self, key)
    end

    return M.with_metatable(t, {
        __index = function(self, key)
            local rt = func(self, key)
            if rt ~= nil then
                return rt
            end
            return fallback(self, key)
        end
    })
end

return M
