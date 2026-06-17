---@class lib.tablex : tablelib
local g = {}

local raw_table = table

for key, value in pairs(raw_table) do
    g[key] = value
end

local function assert_table(value, name)
    assert(type(value) == "table", string.format("%s must be table", name))
end

local function key_order_rank(value)
    local tp = type(value)
    if tp == "number" then
        return 1
    elseif tp == "string" then
        return 2
    elseif tp == "boolean" then
        return 3
    end
    return 4
end

local function sorted_key_less(a, b)
    local rank_a = key_order_rank(a)
    local rank_b = key_order_rank(b)
    if rank_a ~= rank_b then
        return rank_a < rank_b
    end

    local tp = type(a)
    if tp == "number" or tp == "string" then
        return a < b
    elseif tp == "boolean" then
        return (a and 1 or 0) < (b and 1 or 0)
    end

    return tostring(a) < tostring(b)
end

---浅合并多个表，后面的同名键覆盖前面的同名键。
---nil 参数会被跳过；返回新表，不修改输入表。
---@param ... table|nil 待合并的表
---@return table result 合并后的新表
g.merge = function(...)
    local result = {}

    for i = 1, select("#", ...) do
        local obj = select(i, ...)
        if obj ~= nil then
            assert_table(obj, "merge argument")
            for key, value in g.sorted_pairs(obj) do
                result[key] = value
            end
        end
    end

    return result
end

---深拷贝一个值。
---table 的键和值都会递归拷贝，并保留原表 metatable；循环引用会被复用。
---@generic T
---@param object T 待拷贝的值
---@return T copied 拷贝后的值
g.clone = function(object)
    local lookup = {}

    local function copy(value)
        if type(value) ~= "table" then
            return value
        elseif lookup[value] then
            return lookup[value]
        end

        local new_table = {}
        lookup[value] = new_table
        for k, v in g.sorted_pairs(value) do
            new_table[copy(k)] = copy(v)
        end

        return setmetatable(new_table, getmetatable(value))
    end

    return copy(object)
end

---递归合并多个表。
---当新旧值都是 table 时继续向下合并，否则后面的值覆盖前面的值。
---nil 参数会被跳过；返回新表，不修改输入表，也不复用输入表中的子表。
---@param ... table|nil 待合并的表
---@return table result 合并后的新表
g.deep_merge = function(...)
    local result = {}

    for i = 1, select("#", ...) do
        local obj = select(i, ...)
        if obj ~= nil then
            assert_table(obj, "deep_merge argument")
            for key, value in g.sorted_pairs(obj) do
                local old = result[key]
                if type(old) == "table" and type(value) == "table" then
                    result[key] = g.deep_merge(old, value)
                elseif type(value) == "table" then
                    result[key] = g.clone(value)
                else
                    result[key] = value
                end
            end
        end
    end

    return result
end

---@generic K, V
---按稳定顺序遍历 table。
---number 键按数值排序，string 键按字典序排序，其它键按 tostring 结果排序。
---@param t table<K, V> 待遍历的表
---@return fun(): K?, V? iterator 迭代器，返回 key 和 value
g.sorted_pairs = function(t)
    assert_table(t, "sorted_pairs argument")

    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end

    raw_table.sort(keys, sorted_key_less)

    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k == nil then
            return nil
        end
        return k, t[k]
    end
end

---判断表是否没有任何键。
---@param t table 待检查的表
---@return boolean empty 是否为空表
g.is_empty = function(t)
    assert_table(t, "is_empty argument")
    return next(t) == nil
end

---统计表中的键值对数量。
---@param t table 待统计的表
---@return integer count 键值对数量
g.count = function(t)
    assert_table(t, "count argument")
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

---@generic K
---@param t table<K, any> 待读取的表
---@return K[] keys 键列表
g.keys = function(t)
    local result = {}
    for key in g.sorted_pairs(t) do
        result[#result + 1] = key
    end
    return result
end

---@generic V
---@param t table<any, V> 待读取的表
---@return V[] values 值列表
g.values = function(t)
    local result = {}
    for _, value in g.sorted_pairs(t) do
        result[#result + 1] = value
    end
    return result
end

---@generic K, V
---@param t table<K, V> 待查找的表
---@param value V 要匹配的值
---@return boolean found 是否存在该值
g.contains = function(t, value)
    assert_table(t, "contains argument")
    for _, item in pairs(t) do
        if item == value then
            return true
        end
    end
    return false
end

---@generic K, V
---@param t table<K, V> 待查找的表
---@param predicate fun(value: V, key: K): boolean 判断函数
---@return V? value 匹配到的值
---@return K? key 匹配到的键
g.find = function(t, predicate)
    for key, value in g.sorted_pairs(t) do
        if predicate(value, key) then
            return value, key
        end
    end
    return nil, nil
end

---@generic K, V
---@param t table<K, V> 待判断的表
---@param predicate fun(value: V, key: K): boolean 判断函数
---@return boolean matched 是否存在任意匹配项
g.any = function(t, predicate)
    for key, value in g.sorted_pairs(t) do
        if predicate(value, key) then
            return true
        end
    end
    return false
end

---@generic K, V
---@param t table<K, V> 待判断的表
---@param predicate fun(value: V, key: K): boolean 判断函数
---@return boolean matched 是否全部匹配
g.all = function(t, predicate)
    for key, value in g.sorted_pairs(t) do
        if not predicate(value, key) then
            return false
        end
    end
    return true
end

---@generic K, V, R
---@param t table<K, V> 待转换的表
---@param mapper fun(value: V, key: K): R 转换函数
---@return table<K, R> result 转换后的表
g.map = function(t, mapper)
    local result = {}
    for key, value in g.sorted_pairs(t) do
        result[key] = mapper(value, key)
    end
    return result
end

---@generic K, V
---@param t table<K, V> 待过滤的表
---@param predicate fun(value: V, key: K): boolean 判断函数
---@return table<K, V> result 过滤后的表
g.filter = function(t, predicate)
    local result = {}
    for key, value in g.sorted_pairs(t) do
        if predicate(value, key) then
            result[key] = value
        end
    end
    return result
end

---@generic K, V
---@param t table<K, V> 待遍历的表
---@param callback fun(value: V, key: K) 回调函数
g.each = function(t, callback)
    for key, value in g.sorted_pairs(t) do
        callback(value, key)
    end
end

---@generic K, V, R
---@param t table<K, V> 待归约的表
---@param reducer fun(acc: R, value: V, key: K): R 归约函数
---@param initial R 初始值
---@return R result 归约结果
g.reduce = function(t, reducer, initial)
    local acc = initial
    for key, value in g.sorted_pairs(t) do
        acc = reducer(acc, value, key)
    end
    return acc
end

return g
