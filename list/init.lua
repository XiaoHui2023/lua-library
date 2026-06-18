---@type lib.tablex
local tablex = require "lib.tablex"
---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.debugx
local debugx = require "lib.debugx"

local table = tablex

---@class lib.list.entry
---@field id integer
---@field value any
---@field alive boolean

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

---@param tb? any[] 参数说明
---@return lib.list
local function create(tb)
    if tb == nil then
        tb = {}
    end
    assert_array(tb)

    ---@class lib.list
    ---@field count integer
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
    ---@return integer? 返回值
    local function find_rank_by_id(id)
        for rank, entry in ipairs(entries) do
            if entry.id == id then
                return rank
            end
        end
        return nil
    end

    ---@param value any
    ---@return integer? 返回值
    local function find_rank_by_element(value)
        for rank, entry in ipairs(entries) do
            if entry.value == value then
                return rank
            end
        end
        return nil
    end

    ---@param rank integer
    ---@return lib.list.entry? 返回值
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
    ---@return any? 返回值
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
    ---@return any? 返回值
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

    ---@return any? 返回值
    ---@return integer? 返回值
    function o.first()
        local entry = entries[1]
        if entry == nil then
            return nil, nil
        end
        return entry.value, 1
    end

    ---@return any? 返回值
    ---@return integer? 返回值
    function o.last()
        local n = count()
        local entry = entries[n]
        if entry == nil then
            return nil, nil
        end
        return entry.value, n
    end

    ---@param value any
    ---@return any? 返回值
    ---@return integer? 返回值
    function o.prev(value)
        local rank = find_rank_by_element(value)
        if rank == nil or rank <= 1 then
            return nil, nil
        end
        local entry = entries[rank - 1]
        return entry.value, rank - 1
    end

    ---@param value any
    ---@return any? 返回值
    ---@return integer? 返回值
    function o.next(value)
        local rank = find_rank_by_element(value)
        if rank == nil or rank >= count() then
            return nil, nil
        end
        local entry = entries[rank + 1]
        return entry.value, rank + 1
    end

    ---@return any? 返回值
    ---@return integer? 返回值
    function o.pop_front()
        local value = o.pop(1)
        if value == nil then
            return nil, nil
        end
        return value, 1
    end

    ---@return any? 返回值
    ---@return integer? 返回值
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

                ---@class lib.list.for_each.context
                ---@field remove fun()
                ---@field set fun(element:any)
                ---@field stop fun():nil
                ---@field index integer
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
    ---@return any? 返回值
    ---@return integer? 返回值
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

    ---@return any? 返回值
    ---@return integer? 返回值
    function o.get_random()
        return random(false)
    end

    ---@return any? 返回值
    ---@return integer? 返回值
    function o.pop_random()
        return random(true)
    end

    ---@param compare? fun(a:any,b:any):boolean? 参数说明
    ---@param reverse? boolean 参数说明
    ---@return lib.list
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

    ---@return lib.list
    function o.reverse()
        local values = {}
        for rank = count(), 1, -1 do
            values[#values + 1] = entries[rank].value
        end
        return create(values)
    end

    ---@param predicate fun(element:any):boolean
    ---@return lib.list
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
    ---@return lib.list
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

    ---@param limit? integer 参数说明
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
    ---@param stop? integer 参数说明
    ---@return lib.list
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
