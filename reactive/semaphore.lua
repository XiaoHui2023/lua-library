local reactive_base = require "reactive.base"
local event = require "reactive.event"
local track = require "reactive.track"

local M = {}

---@param args? { name?: string }
---@return table
function M.new(args)
    args = args or {}

    local count = 0
    local base = reactive_base.new({ name = args.name or "" })
    local on_acquire = event.new({ name = (args.name or "") .. ".acquire" })
    local on_release = event.new({ name = (args.name or "") .. ".release" })
    local on_change = event.new({ name = (args.name or "") .. ".change" })
    local on_dispose = event.new({ mode = "once", name = (args.name or "") .. ".dispose" })
    local disposed = false

    local o = {
        type = "semaphore",
        on_acquire = on_acquire.as_listener(),
        on_release = on_release.as_listener(),
        on_change = on_change.as_listener(),
        on_dispose = on_dispose.as_listener(),
    }

    local function touch_change(new_count, old_count)
        base.touch()
        on_change.run(new_count, old_count)
    end

    function o.get_name()
        return base.get_name()
    end

    function o.set_name(name)
        base.set_name(name)
    end

    function o.get_version()
        return base.get_version()
    end

    function o.is_disposed()
        return disposed
    end

    function o.track()
        if disposed then
            return
        end
        track.register(o)
    end

    function o.count()
        o.track()
        return count
    end

    function o.is_acquired()
        o.track()
        return count > 0
    end

    function o.is_free()
        o.track()
        return count == 0
    end

    function o.acquire()
        if disposed then
            return function() end
        end

        local old_count = count
        count = count + 1
        touch_change(count, old_count)

        if count == 1 then
            on_acquire.run()
        end

        local acquired = true
        return function()
            if not acquired or disposed then
                return
            end

            acquired = false
            local old_release_count = count
            count = count - 1
            touch_change(count, old_release_count)

            if count == 0 then
                on_release.run()
            end
        end
    end

    function o.toggle_on_event(source_event, should_acquire)
        local release
        local dispose = event.once({ name = (args.name or "") .. ".toggle.dispose" })

        dispose.add(source_event.add(function(...)
            if should_acquire(...) then
                if release == nil then
                    release = o.acquire()
                end
            elseif release ~= nil then
                release()
                release = nil
            end
        end))

        dispose.add(function()
            if release ~= nil then
                release()
                release = nil
            end
        end)

        return dispose
    end

    function o.dispose()
        if disposed then
            return
        end
        disposed = true
        count = 0
        on_dispose.run()
        on_acquire.clear()
        on_release.clear()
        on_change.clear()
        on_dispose.clear()
        base.mark_disposed()
    end

    setmetatable(o, {
        __index = function(_, key)
            if key == "count" then
                return o.count()
            end
            if key == "is_acquired" then
                return o.is_acquired()
            end
            if key == "is_free" then
                return o.is_free()
            end
            return nil
        end,
        __call = function()
            return o.acquire()
        end,
    })

    return o
end

return M
