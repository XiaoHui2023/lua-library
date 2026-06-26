local event = require "reactive.event"
local track = require "reactive.track"
local base = require "reactive.base"
local ref = require "reactive.ref"
local list_ref = require "reactive.list_ref"
local table_ref = require "reactive.table_ref"
local computed = require "reactive.computed"
local semaphore = require "reactive.semaphore"
local factory = require "reactive.factory"
local scope = require "reactive.scope"
local collection = require "reactive.collection"
local timer = require "reactive.timer"

---@alias reactive.set<T> lib.reactive.ref<T>
---@alias reactive.ref<T> lib.reactive.ref<T>
---@alias reactive.event<T> lib.reactive.event<T>
---@alias reactive.once_event<T> lib.reactive.event<T>
---@alias reactive.computed<T> lib.reactive.computed<T>
---@alias reactive.add<T> lib.reactive.collection<T>
---@alias reactive.collection<T> lib.reactive.collection<T>
---@alias reactive.semaphore lib.reactive.semaphore
---@alias reactive.scope lib.reactive.scope
---@alias reactive.factory lib.reactive.factory
---@alias lib.reactive.set<T> lib.reactive.ref<T>
---@alias lib.reactive.add<T> lib.reactive.collection<T>
---@alias lib.reactive.once_event<T> lib.reactive.event<T>
---@alias hook.set<T> lib.reactive.ref<T>
---@alias hook.event<T> lib.reactive.event<T>
---@alias hook.once_event<T> lib.reactive.event<T>
---@alias hook.computed<T> lib.reactive.computed<T>
---@alias hook.add<T> lib.reactive.collection<T>
---@alias hook.semaphore lib.reactive.semaphore
---@alias hook.factory lib.reactive.factory

---@class lib.reactive
local M = {
    event = event.new,
    once_event = event.once,
    set_event_error_handler = event.set_error_handler,
    track = track,
    reactive = base.new,
    reactive_model = base.new,
    ref = ref.new,
    list_ref = list_ref.new,
    table_ref = table_ref.new,
    list = list_ref.new,
    table = table_ref.new,
    collection = collection.new,
    computed = computed.new,
    flush_frame_computed = computed.flush_frame,
    has_frame_computed_jobs = computed.has_frame_jobs,
    set_computed_frame_scheduler = computed.set_frame_scheduler,
    semaphore = semaphore.new,
    factory = factory.new,
    set_factory_timer_loop = factory.set_timer_loop,
    set_factory_timer_driver = factory.set_timer_driver,
    timer = timer.new,
    set_timer_driver = timer.set_driver,
    scope = scope.new,
}

function M.var(args)
    args = args or {}
    local default = args.default
    if type(default) == "function" and args.unpackFunc then
        default = default()
    end
    local o = ref.new({ value = default, name = args.name })
    if args.override and args.override.set then
        o.override("set", args.override.set)
    end
    if args.immediateDefault then
        o.set(default)
    end
    return o
end

function M.is_instance_of(value, class_name)
    return type(value) == "table" and (value.class_name == class_name or value.type == class_name)
end

return M
