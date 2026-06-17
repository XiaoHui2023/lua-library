---版本号、touch 与读取时依赖登记

local track = require "reactive.track"

local M = {}

---@param args? { name?: string }
---@return table
function M.new(args)
    args = args or {}
    local version = 0
    local name = args.name or ""
    local disposed = false

    local o = {
        type = "reactive",
    }

    function o.get_name()
        return name
    end

    function o.set_name(value)
        name = value or ""
    end

    function o.get_version()
        return version
    end

    function o.touch()
        if disposed then
            return
        end
        version = version + 1
    end

    function o.track()
        if disposed then
            return
        end
        track.register(o)
    end

    function o.is_disposed()
        return disposed
    end

    function o.mark_disposed()
        disposed = true
    end

    return o
end

return M
