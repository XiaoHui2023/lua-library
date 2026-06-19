---@type lib.tablex
local tablex = require "lib.tablex"
---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.debugx
local debugx = require "lib.debugx"

local table = tablex

---@class lib.list.entry
---@field id integer 元素唯一编号
---@field value any 元素值
---@field alive boolean 元素是否仍在列表中

---@class lib.list.for_each.context
---@field remove fun() 删除当前元素
---@field set fun(element:any) 替换当前元素
---@field stop fun():nil 停止后续遍历
---@field index integer 当前元素在遍历快照中的序号

---@alias lib.list.compare<T> fun(a:T,b:T):boolean

---@class lib.list<T>
---@field count integer 当前元素数量
---@field clear fun() 清空列表
---@field get_rank_by_id fun():table<integer, integer> 获取编号到序号的映射
---@field get_element_by_id fun():table<integer, T> 获取编号到元素的映射
---@field set_debug_mode fun(enable:boolean) 设置调试模式
---@field get_debug_mode fun():boolean 获取调试模式是否启用
---@field swap fun(rank_i:integer, rank_j:integer) 交换两个序号上的元素
---@field index fun(rank:integer):T? 按序号读取元素
---@field insert fun(rank:integer, value:T):fun():nil 按序号插入元素并返回删除函数
---@field pop fun(rank:integer):T? 删除并返回指定序号的元素
---@field remove fun(value:T):boolean 删除指定元素
---@field contains fun(value:T):boolean 判断是否包含元素
---@field first fun():T?, integer? 获取第一个元素及其序号
---@field last fun():T?, integer? 获取最后一个元素及其序号
---@field prev fun(value:T):T?, integer? 获取指定元素的前一个元素及其序号
---@field next fun(value:T):T?, integer? 获取指定元素的后一个元素及其序号
---@field pop_front fun():T?, integer? 删除并返回第一个元素及其序号
---@field pop_back fun():T?, integer? 删除并返回最后一个元素及其序号
---@field append fun(value:T):fun():nil 追加元素并返回删除函数
---@field for_each fun(on_each:fun(element:T, context:lib.list.for_each.context)) 遍历元素快照
---@field get_random fun():T?, integer? 随机读取元素及其序号
---@field pop_random fun():T?, integer? 随机删除并返回元素及其序号
---@field sort fun(compare?:lib.list.compare<T>, reverse?:boolean):lib.list<T> 原地稳定排序
---@field reverse fun():lib.list<T> 返回反序后的新列表
---@field filter fun(predicate:fun(element:T):boolean):lib.list<T> 过滤元素并返回新列表
---@field map fun(map_func:fun(element:T):any):lib.list<any> 映射元素并返回新列表
---@field empty fun():boolean 判断列表是否为空
---@field any fun():boolean 判断列表是否存在元素
---@field to_table fun():T[] 导出数组
---@field shuffle fun(limit?:integer) 随机打乱前若干个元素
---@field slice fun(start:integer, stop?:integer):lib.list<T> 截取子列表
---@field print fun() 打印列表内容

---@alias list<T> lib.list<T>

---@param value any
local function assert_element(value)
    assert(value ~= nil, "list element must not be nil")
end

---@param value any
---@param name string
local function assert_integer(value, name)
    assert(type(value) == "number", name .. " must be number")
    assert(value == math.floor(value), name .. " must be integer")
end

---@param value any
---@param name string
local function assert_function(value, name)
    assert(type(value) == "function", name .. " must be function")
end

---@param value any
---@param name string
local function assert_optional_function(value, name)
    assert(value == nil or type(value) == "function", name .. " must be function")
end

---@param rank any
---@param count integer
local function assert_insert_rank(rank, count)
    assert_integer(rank, "rank")
    assert(rank >= 1 and rank <= count + 1, "rank out of bounds")
end

---@param tb table
local function assert_array(tb)
    assert(type(tb) == "table", "list source must be table")

    local max_index = 0
    local key_count = 0
    for key in pairs(tb) do
        assert(type(key) == "number" and key >= 1 and key == math.floor(key), "list source must be an array")
        if key > max_index then
            max_index = key
        end
        key_count = key_count + 1
    end

    assert(key_count == max_index, "list source must not contain holes")
end

---@generic T
---@param items T[]
---@param less fun(a:T,b:T):boolean
---@return T[]
local function stable_sort(items, less)
    local sorted = {}
    for _, value in ipairs(items) do
        local insert_at = #sorted + 1
        for index = 1, #sorted do
            if less(value, sorted[index]) then
                insert_at = index
                break
            end
        end
        table.insert(sorted, insert_at, value)
    end
    return sorted
end

---@generic T
---@param tb? T[] 初始数组；省略时创建空列表
---@return lib.list<T>
local function create(tb)
    if tb == nil then
        tb = {}
    end
    assert_array(tb)

    local o = {}

    ---@type lib.list.entry[]
    local entries = {}
    ---@type table<integer, lib.list.entry>
    local entry_by_id = {}
    local next_id = 1
    local debug_mode_count = 0

    local function count()
        return #entries
    end

    ---@param rank integer
    ---@param name? string 错误信息中使用的参数名
    ---@return integer
    local function clamp_rank(rank, name)
        assert_integer(rank, name or "rank")
        local n = count()
        if n == 0 then
            return 0
        end
        if rank < 1 then
            return 1
        end
        if rank > n then
            return n
        end
        return rank
    end

    ---@param id integer
    ---@return integer? rank 找到时返回元素序号
    local function find_rank_by_id(id)
        for rank, entry in ipairs(entries) do
            if entry.id == id then
                return rank
            end
        end
        return nil
    end

    ---@param value any
    ---@return integer? rank 找到时返回元素序号
    local function find_rank_by_element(value)
        for rank, entry in ipairs(entries) do
            if entry.value == value then
                return rank
            end
        end
        return nil
    end

    ---@param rank integer
    ---@return lib.list.entry? entry 找到时返回内部条目
    local function get_entry_by_rank(rank)
        return entries[rank]
    end

    ---@param rank integer
    ---@param value any
    ---@return integer
    local function insert_entry(rank, value)
        local id = next_id
        next_id = next_id + 1

        local entry = {
            id = id,
            value = value,
            alive = true,
        }
        entry_by_id[id] = entry
        table.insert(entries, rank, entry)
        return id
    end

    ---@param id integer
    ---@return boolean
    local function remove_by_id(id)
        local entry = entry_by_id[id]
        if entry == nil or not entry.alive then
            return false
        end

        local rank = find_rank_by_id(id)
        if rank == nil then
            return false
        end

        entry.alive = false
        entry_by_id[id] = nil
        table.remove(entries, rank)
        return true
    end

    ---@param rank integer
    ---@return boolean
    local function remove_by_rank(rank)
        local entry = get_entry_by_rank(rank)
        if entry == nil then
            return false
        end
        return remove_by_id(entry.id)
    end

    ---@param value any
    ---@return fun():nil
    local function make_delete_handler(value)
        local id = insert_entry(count() + 1, value)
        local removed = false
        return function()
            if removed then
                return
            end
            removed = true
            remove_by_id(id)
        end
    end

    function o.clear()
        entries = {}
        entry_by_id = {}
    end

    function o.get_rank_by_id()
        local result = {}
        for rank, entry in ipairs(entries) do
            result[entry.id] = rank
        end
        return result
    end

    function o.get_element_by_id()
        local result = {}
        for _, entry in ipairs(entries) do
            result[entry.id] = entry.value
        end
        return result
    end

    ---@param enable boolean
    function o.set_debug_mode(enable)
        assert(type(enable) == "boolean", "enable must be boolean")
        if enable then
            debug_mode_count = debug_mode_count + 1
        else
            debug_mode_count = math.max(0, debug_mode_count - 1)
        end
    end

    function o.get_debug_mode()
        return debug_mode_count > 0
    end

    ---@param rank_i integer
    ---@param rank_j integer
    function o.swap(rank_i, rank_j)
        local n = count()
        if n == 0 then
            assert_integer(rank_i, "rank_i")
            assert_integer(rank_j, "rank_j")
            return
        end
        rank_i = clamp_rank(rank_i, "rank_i")
        rank_j = clamp_rank(rank_j, "rank_j")
        if rank_i == rank_j then
            return
        end
        entries[rank_i], entries[rank_j] = entries[rank_j], entries[rank_i]
    end

    ---@param rank integer
    ---@return any? value 找到时返回元素值
    function o.index(rank)
        assert_integer(rank, "rank")
        local entry = get_entry_by_rank(rank)
        if entry == nil then
            return nil
        end
        return entry.value
    end

    ---@param rank integer
    ---@param value any
    ---@return fun():nil
    function o.insert(rank, value)
        assert_insert_rank(rank, count())
        assert_element(value)

        local id = insert_entry(rank, value)
        local removed = false
        return function()
            if removed then
                return
            end
            removed = true
            remove_by_id(id)
        end
    end

    ---@param rank integer
    ---@return any? value 被删除的元素值
    function o.pop(rank)
        assert_integer(rank, "rank")
        local entry = get_entry_by_rank(rank)
        if entry == nil then
            return nil
        end

        local value = entry.value
        remove_by_rank(rank)
        return value
    end

    ---@param value any
    ---@return boolean
    function o.remove(value)
        local rank = find_rank_by_element(value)
        if rank == nil then
            return false
        end
        return remove_by_rank(rank)
    end

    ---@param value any
    ---@return boolean
    function o.contains(value)
        return find_rank_by_element(value) ~= nil
    end

    ---@return any? value 第一个元素值
    ---@return integer? rank 第一个元素序号
    function o.first()
        local entry = entries[1]
        if entry == nil then
            return nil, nil
        end
        return entry.value, 1
    end

    ---@return any? value 最后一个元素值
    ---@return integer? rank 最后一个元素序号
    function o.last()
        local n = count()
        local entry = entries[n]
        if entry == nil then
            return nil, nil
        end
        return entry.value, n
    end

    ---@param value any
    ---@return any? value 前一个元素值
    ---@return integer? rank 前一个元素序号
    function o.prev(value)
        local rank = find_rank_by_element(value)
        if rank == nil or rank <= 1 then
            return nil, nil
        end
        local entry = entries[rank - 1]
        return entry.value, rank - 1
    end

    ---@param value any
    ---@return any? value 后一个元素值
    ---@return integer? rank 后一个元素序号
    function o.next(value)
        local rank = find_rank_by_element(value)
        if rank == nil or rank >= count() then
            return nil, nil
        end
        local entry = entries[rank + 1]
        return entry.value, rank + 1
    end

    ---@return any? value 第一个元素值
    ---@return integer? rank 第一个元素序号
    function o.pop_front()
        local value = o.pop(1)
        if value == nil then
            return nil, nil
        end
        return value, 1
    end

    ---@return any? value 最后一个元素值
    ---@return integer? rank 最后一个元素序号
    function o.pop_back()
        local rank = count()
        local value = o.pop(rank)
        if value == nil then
            return nil, nil
        end
        return value, rank
    end

    ---@param value any
    ---@return fun():nil
    function o.append(value)
        assert_element(value)
        return make_delete_handler(value)
    end

    ---@param on_each fun(element:any,context:lib.list.for_each.context)
    function o.for_each(on_each)
        assert_function(on_each, "on_each")

        local snapshot = {}
        for rank, entry in ipairs(entries) do
            snapshot[#snapshot + 1] = {
                id = entry.id,
                rank = rank,
            }
        end

        local should_stop = false
        for _, item in ipairs(snapshot) do
            local entry = entry_by_id[item.id]
            if entry ~= nil and entry.alive then
                local removed = false

                ---@type lib.list.for_each.context
                local ctx = {
                    remove = function()
                        if removed then
                            return
                        end
                        removed = remove_by_id(item.id)
                    end,
                    set = function(value)
                        assert_element(value)
                        local current = entry_by_id[item.id]
                        if current == nil or not current.alive then
                            return
                        end
                        current.value = value
                    end,
                    stop = function()
                        should_stop = true
                    end,
                    index = item.rank,
                }

                on_each(entry.value, ctx)
            end

            if should_stop then
                return
            end
        end
    end

    ---@param should_remove boolean
    ---@return any? value 随机选中的元素值
    ---@return integer? rank 随机选中的元素序号
    local function random(should_remove)
        local n = count()
        if n == 0 then
            return nil, nil
        end

        local rank = math.random(1, n)
        local entry = entries[rank]
        local value = entry.value
        if should_remove then
            remove_by_rank(rank)
        end
        return value, rank
    end

    ---@return any? value 随机选中的元素值
    ---@return integer? rank 随机选中的元素序号
    function o.get_random()
        return random(false)
    end

    ---@return any? value 随机删除的元素值
    ---@return integer? rank 随机删除的元素序号
    function o.pop_random()
        return random(true)
    end

    ---@param compare? fun(a:any,b:any):boolean 比较函数；返回 true 表示 a 排在 b 前面
    ---@param reverse? boolean 是否反向排序
    ---@return lib.list<any>
    ---@nodiscard
    function o.sort(compare, reverse)
        assert_optional_function(compare, "compare")
        assert(reverse == nil or type(reverse) == "boolean", "reverse must be boolean")

        local wrapped = {}
        for rank, entry in ipairs(entries) do
            wrapped[rank] = {
                entry = entry,
                value = entry.value,
                order = rank,
            }
        end

        wrapped = stable_sort(wrapped, function(a, b)
            if compare ~= nil then
                if reverse then
                    if compare(b.value, a.value) then
                        return true
                    end
                    if compare(a.value, b.value) then
                        return false
                    end
                else
                    if compare(a.value, b.value) then
                        return true
                    end
                    if compare(b.value, a.value) then
                        return false
                    end
                end
                return a.order < b.order
            end

            if reverse then
                return a.order > b.order
            end
            return a.order < b.order
        end)

        local sorted_entries = {}
        for index, item in ipairs(wrapped) do
            sorted_entries[index] = item.entry
        end
        entries = sorted_entries
        return o
    end

    ---@return lib.list<any>
    function o.reverse()
        local values = {}
        for rank = count(), 1, -1 do
            values[#values + 1] = entries[rank].value
        end
        return create(values)
    end

    ---@param predicate fun(element:any):boolean
    ---@return lib.list<any>
    function o.filter(predicate)
        assert_function(predicate, "predicate")

        local new = create()
        o.for_each(function(value)
            if predicate(value) then
                new.append(value)
            end
        end)
        return new
    end

    ---@param map_func fun(element:any):any
    ---@return lib.list<any>
    function o.map(map_func)
        assert_function(map_func, "map_func")

        local new = create()
        o.for_each(function(value)
            local mapped = map_func(value)
            assert_element(mapped)
            new.append(mapped)
        end)
        return new
    end

    ---@return boolean
    function o.empty()
        return count() == 0
    end

    ---@return boolean
    function o.any()
        return count() > 0
    end

    ---@return table
    function o.to_table()
        local result = {}
        for rank, entry in ipairs(entries) do
            result[rank] = entry.value
        end
        return result
    end

    ---@param limit? integer 只打乱前 limit 个元素；省略时打乱整个列表
    function o.shuffle(limit)
        if limit == nil then
            limit = count()
        end
        assert_integer(limit, "limit")
        if limit > count() then
            limit = count()
        end
        if limit <= 1 then
            return
        end

        for rank = limit, 2, -1 do
            o.swap(rank, math.random(rank))
        end
    end

    ---@param start integer
    ---@param stop? integer 结束序号；省略时截取到列表末尾
    ---@return lib.list<any>
    function o.slice(start, stop)
        if stop == nil then
            stop = count()
        end
        start = clamp_rank(start, "start")
        stop = clamp_rank(stop, "stop")
        if count() == 0 then
            return create()
        end

        local values = {}
        if start <= stop then
            for rank = start, stop do
                values[#values + 1] = entries[rank].value
            end
        end
        return create(values)
    end

    function o.print()
        debugx.print(o.get_element_by_id())
    end

    for _, value in ipairs(tb) do
        o.append(value)
    end

    metatablex.index_proxy(o, function(_, key)
        if key == "count" then
            return count()
        end
    end)

    metatablex.with_tostring(o, function()
        local parts = {}
        o.for_each(function(value)
            parts[#parts + 1] = tostring(value)
        end)
        return string.format("[%s]", table.concat(parts, ", "))
    end)

    metatablex.lock_new_fields(o)

    return o
end

return create
