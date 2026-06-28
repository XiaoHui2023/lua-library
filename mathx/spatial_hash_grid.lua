local M = {}

local function cell_key(cell_x, cell_y)
    return tostring(cell_x) .. ":" .. tostring(cell_y)
end

---@class lib.mathx.spatial_hash_grid.options
---@field cell_size? number
---@field get_position? fun(item:any):lib.point
---@field get_radius? fun(item:any):number

---@param args? lib.mathx.spatial_hash_grid.options
---@return lib.mathx.spatial_hash_grid
function M.create(args)
    args = args or {}
    local cell_size = args.cell_size or 128
    assert(cell_size > 0, "spatial hash grid cell_size must be positive")

    local get_position = args.get_position or function(item)
        return item.position
    end
    local get_radius = args.get_radius or function(item)
        return item.radius or 0
    end
    local cells = {}
    local records = {}
    local o = {}

    local function get_cell(cell_x, cell_y)
        local key = cell_key(cell_x, cell_y)
        local cell = cells[key]
        if cell == nil then
            cell = {}
            cells[key] = cell
        end
        return cell, key
    end

    local function bounds_for(item)
        local position = get_position(item)
        local radius = get_radius(item)
        local x = position.x or 0
        local y = position.y or 0
        return math.floor((x - radius) / cell_size),
            math.floor((y - radius) / cell_size),
            math.floor((x + radius) / cell_size),
            math.floor((y + radius) / cell_size)
    end

    local function remove_record(item)
        local record = records[item]
        if record == nil then
            return
        end
        for _, key in ipairs(record.keys) do
            local cell = cells[key]
            if cell ~= nil then
                cell[item] = nil
            end
        end
        records[item] = nil
    end

    local function add_record(item)
        local min_x, min_y, max_x, max_y = bounds_for(item)
        local keys = {}
        for cell_x = min_x, max_x do
            for cell_y = min_y, max_y do
                local cell, key = get_cell(cell_x, cell_y)
                cell[item] = true
                keys[#keys + 1] = key
            end
        end
        records[item] = {
            min_x = min_x,
            min_y = min_y,
            max_x = max_x,
            max_y = max_y,
            keys = keys,
        }
    end

    function o.insert(item)
        remove_record(item)
        add_record(item)
    end

    function o.remove(item)
        remove_record(item)
    end

    function o.update(item)
        local record = records[item]
        if record == nil then
            add_record(item)
            return
        end
        local min_x, min_y, max_x, max_y = bounds_for(item)
        if record.min_x == min_x and record.min_y == min_y and record.max_x == max_x and record.max_y == max_y then
            return
        end
        remove_record(item)
        add_record(item)
    end

    function o.clear()
        cells = {}
        records = {}
    end

    ---@param position lib.point
    ---@param radius number
    ---@param visitor fun(item:any)
    function o.visit_circle_candidates(position, radius, visitor)
        local x = position.x or 0
        local y = position.y or 0
        local min_x = math.floor((x - radius) / cell_size)
        local min_y = math.floor((y - radius) / cell_size)
        local max_x = math.floor((x + radius) / cell_size)
        local max_y = math.floor((y + radius) / cell_size)
        local visited = {}
        for cell_x = min_x, max_x do
            for cell_y = min_y, max_y do
                local cell = cells[cell_key(cell_x, cell_y)]
                if cell ~= nil then
                    for item in pairs(cell) do
                        if not visited[item] then
                            visited[item] = true
                            visitor(item)
                        end
                    end
                end
            end
        end
    end

    return o
end

return M
