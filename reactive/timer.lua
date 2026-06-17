local M = {}

local timer_driver
local default_interval_time = 0.01

local function assert_interval_time(interval_time)
    assert(type(interval_time) == "number" and interval_time > 0, "reactive timer interval must be positive")
end

local function destroy_raw_handle(raw_handle)
    if raw_handle == nil then
        return
    end
    if type(raw_handle) == "function" then
        raw_handle()
        return
    end
    if type(raw_handle) ~= "table" then
        return
    end
    if raw_handle.dispose ~= nil then
        raw_handle.dispose()
    elseif raw_handle.delete ~= nil then
        raw_handle.delete()
    elseif raw_handle.remove ~= nil then
        raw_handle.remove(raw_handle)
    elseif raw_handle.pause ~= nil then
        raw_handle.pause(raw_handle)
    end
end

local function normalize_driver(driver)
    if driver == nil then
        return nil
    end
    if type(driver) == "function" then
        return {
            register = function(trigger, interval_time)
                return driver(trigger, interval_time)
            end,
            destroy = destroy_raw_handle,
        }
    end
    assert(type(driver) == "table", "reactive timer driver must be a table or function")
    assert(type(driver.register) == "function", "reactive timer driver.register must be a function")
    return {
        register = driver.register,
        trigger = driver.trigger,
        destroy = driver.destroy or destroy_raw_handle,
    }
end

---@param driver? table|fun(trigger: fun(), interval_time: number): any
---@param interval_time? number
function M.set_driver(driver, interval_time)
    timer_driver = normalize_driver(driver)
    if interval_time ~= nil then
        assert_interval_time(interval_time)
        default_interval_time = interval_time
    end
end

---@param loop_func? fun(trigger: fun(), interval_time: number): any
---@param interval_time? number
function M.set_loop(loop_func, interval_time)
    M.set_driver(loop_func, interval_time)
end

function M.get_default_interval_time()
    return default_interval_time
end

---@param args { action: fun(...), interval_time?: number, name?: string }
---@return table
function M.new(args)
    args = args or {}
    assert(type(args.action) == "function", "reactive timer action must be a function")
    assert(timer_driver ~= nil, "reactive timer driver is not injected")

    local driver = timer_driver
    local disposed = false
    local interval_time = args.interval_time or default_interval_time
    assert_interval_time(interval_time)

    local o = {
        type = "timer",
        name = args.name or "",
    }

    function o.trigger(...)
        if disposed then
            return
        end
        if driver.trigger ~= nil then
            return driver.trigger(args.action, o, ...)
        end
        return args.action(...)
    end

    local raw_handle = driver.register(o.trigger, interval_time, o)

    function o.dispose()
        if disposed then
            return
        end
        disposed = true
        driver.destroy(raw_handle, o)
        raw_handle = nil
    end

    function o.delete()
        o.dispose()
    end

    function o.clear()
        o.dispose()
    end

    function o.is_disposed()
        return disposed
    end

    function o.get_interval_time()
        return interval_time
    end

    setmetatable(o, {
        __call = function(_, ...)
            return o.trigger(...)
        end,
    })

    return o
end

return M
