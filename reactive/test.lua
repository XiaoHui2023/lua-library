local source = debug.getinfo(1, "S").source
local reactive_dir = source:sub(1, 1) == "@" and source:sub(2) or source
reactive_dir = reactive_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = reactive_dir:match("^(.*)[/\\][^/\\]+$") or reactive_dir
package.path = library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local reactive = require "reactive"

local function assert_same(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_same") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

local value = reactive.ref({ value = 1, name = "value" })
local doubled_updates = 0
local doubled_changes = 0
local doubled = reactive.computed({
    name = "doubled",
    expr = function()
        return value() * 2
    end,
})

doubled.on_update(function(new_value, old_value)
    doubled_updates = doubled_updates + 1
    assert_same(new_value, value() * 2, "computed update should receive new value")
    if old_value ~= nil then
        assert_same(old_value, 2, "computed update should receive old value")
    end
end)

doubled.on_change(function(new_value, old_value)
    doubled_changes = doubled_changes + 1
    assert_same(new_value, 4, "computed change should receive new value")
    assert_same(old_value, 2, "computed change should receive old value")
end)

assert_same(doubled(), 2, "computed should evaluate lazily")
value.set(2)
assert(doubled.is_dirty(), "computed should become dirty after dependency change")
assert_same(doubled(), 4, "computed should recompute on read")
assert_same(doubled_updates, 2, "computed should update on each recompute")
assert_same(doubled_changes, 1, "computed should only change after cached value differs")

local tuple = reactive.ref(1, 2)
local tuple_new_a
local tuple_old_a
tuple.on_change.add(function(new_a, _, old_a)
    tuple_new_a = new_a
    tuple_old_a = old_a
end)
tuple.set(3, 4)
assert_same(tuple_new_a, 3, "tuple ref should emit new values")
assert_same(tuple_old_a, 1, "tuple ref should emit old values after new values")

local normalized = reactive.ref({ value = 0 })
normalized.normalize(function(value)
    return math.max(0, value)
end)
normalized.set(-1)
assert_same(normalized(), 0, "ref normalize should transform writes")

local position = reactive.ref({ x = 1, y = 2 })
local position_changes = 0
position.wrap_equal(function(new_position, old_position)
    return old_position ~= nil
        and new_position.x == old_position.x
        and new_position.y == old_position.y
end)
position.on_change.add(function()
    position_changes = position_changes + 1
end)
position.set({ x = 1, y = 2 })
assert_same(position_changes, 1, "ref wrap_equal should skip equivalent table values")
position.set({ x = 2, y = 2 })
assert_same(position_changes, 2, "ref wrap_equal should still emit changed values")

local table_ref = reactive.table()
table_ref.set("row", 1, "cell")
assert_same(table_ref.get("row", 1), "cell", "table ref should support multi-part keys")

local collection = reactive.collection({
    compare = function(a, b)
        return a < b
    end,
})
local added_value
collection.on_add(function(value)
    added_value = value
end)
local remove_two = collection.add(2)
collection.add(1)
assert_same(added_value, 1, "collection should emit add events")
assert_same(collection().first(), 1, "collection should keep sorted order")
remove_two()
assert_same(collection.count(), 1, "collection remove token should remove added item")

local frame_value = reactive.ref({ value = 1, name = "frame.value" })
local frame_runs = 0
local frame_computed = reactive.computed({
    name = "frame.computed",
    flush = "frame",
    expr = function()
        frame_runs = frame_runs + 1
        return frame_value() + 1
    end,
})
assert_same(frame_computed(), 2, "frame computed should have initial value")
frame_value.set(2)
assert(reactive.has_frame_computed_jobs(), "frame computed should enqueue after dependency change")
reactive.flush_frame_computed()
assert_same(frame_computed(), 3, "frame computed should be updated by flush")
assert_same(frame_runs, 2, "frame computed should run once during flush")

local scheduled_flush
reactive.set_computed_frame_scheduler(function(flush)
    scheduled_flush = flush
end)
local scheduled_value = reactive.ref({ value = 1, name = "scheduled.value" })
local scheduled_computed = reactive.computed({
    name = "scheduled.computed",
    flush = "frame",
    expr = function()
        return scheduled_value() + 10
    end,
})
assert_same(scheduled_computed(), 11, "scheduled frame computed should have initial value")
scheduled_value.set(2)
assert(type(scheduled_flush) == "function", "frame scheduler should receive a flush callback")
scheduled_flush()
assert_same(scheduled_computed(), 12, "scheduled frame flush callback should update computed")

local event_errors = {}
reactive.set_event_error_handler(function(err, info)
    table.insert(event_errors, {
        err = err,
        name = info.name,
        phase = info.phase,
    })
end)

reactive.set_computed_frame_scheduler(function()
    error("scheduler failed")
end)
scheduled_value.set(3)
assert(reactive.has_frame_computed_jobs(), "failing frame scheduler should leave frame jobs queued")
assert(event_errors[#event_errors].err:find("scheduler failed", 1, true), "failing frame scheduler should be reported")
local recovered_flush
reactive.set_computed_frame_scheduler(function(flush)
    recovered_flush = flush
end)
assert(type(recovered_flush) == "function", "setting a scheduler should schedule existing frame jobs")
recovered_flush()
assert_same(scheduled_computed(), 13, "scheduler recovery should flush queued jobs")
reactive.set_computed_frame_scheduler(nil)

local event_continue = reactive.event({ name = "event.continue" })
local event_continue_count = 0
event_continue.add(function()
    error("boom")
end)
event_continue.add(function()
    event_continue_count = event_continue_count + 1
end)
event_continue()
assert_same(event_continue_count, 1, "event should continue after subscriber errors")
assert_same(event_errors[#event_errors].name, "event.continue", "event error handler should receive event name")
assert_same(event_errors[#event_errors].phase, "run", "event error handler should receive run phase")

local once = reactive.once_event({ name = "once" })
local once_count = 0
once.add(function()
    once_count = once_count + 1
    error("boom")
end)
once()
once()
assert_same(once_count, 1, "once event subscriber should be removed after errors")

local leak_event = reactive.event({ name = "add_and_run" })
local leak_count = 0
leak_event.add_and_run(function()
    leak_count = leak_count + 1
    error("boom")
end)
leak_event()
assert_same(leak_count, 1, "add_and_run should unsubscribe when the immediate action errors")

local replay_once = reactive.event({ mode = "once", replay = true, name = "replay.once" })
replay_once("first")
local replay_once_count = 0
replay_once.add(function(value)
    replay_once_count = replay_once_count + 1
    assert_same(value, "first", "replay once should receive the last event args")
end)
replay_once("second")
assert_same(replay_once_count, 1, "replay once subscriber should not run again after replay")

local replay_error = reactive.event({ mode = "once", replay = true, name = "replay.error" })
replay_error("first")
local replay_error_count = 0
replay_error.add(function()
    replay_error_count = replay_error_count + 1
    error("boom")
end)
replay_error("second")
assert_same(replay_error_count, 1, "replay once error subscriber should be removed")
assert_same(event_errors[#event_errors].phase, "replay", "event error handler should receive replay phase")
reactive.set_event_error_handler(nil)

local disposed_ref = reactive.ref({ value = 1, name = "disposed.ref" })
disposed_ref.dispose()
disposed_ref.set(2)
assert_same(disposed_ref.raw_get(), 1, "disposed ref should ignore writes")

local disposed_list = reactive.list({ value = { 1 }, name = "disposed.list" })
disposed_list.dispose()
disposed_list.append(2)
assert_same(disposed_list.count(), 0, "disposed list should stay cleared")

local disposed_table = reactive.table({ value = { a = 1 }, name = "disposed.table" })
disposed_table.dispose()
disposed_table.set("b", 2)
assert_same(disposed_table.get("b"), nil, "disposed table should ignore writes")

local gate = reactive.semaphore({ name = "gate" })
local is_locked = reactive.computed({
    name = "gate.locked",
    expr = function()
        return gate.is_acquired()
    end,
})
assert_same(is_locked(), false, "semaphore should be initially free")
local release = gate.acquire()
assert_same(is_locked(), true, "semaphore acquire should dirty computed readers")
release()
assert_same(is_locked(), false, "semaphore release should dirty computed readers")
gate.dispose()

local timer_registered = {}
local timer_destroyed = 0
local timer_triggered = 0
reactive.set_factory_timer_driver({
    register = function(trigger, interval_time)
        local raw_handle = {
            trigger = trigger,
            interval_time = interval_time,
        }
        table.insert(timer_registered, raw_handle)
        return raw_handle
    end,
    trigger = function(action, timer_model)
        timer_triggered = timer_triggered + 1
        action(timer_model.get_interval_time())
    end,
    destroy = function()
        timer_destroyed = timer_destroyed + 1
    end,
}, 0.05)

local root = reactive.factory({ name = "root" })
root.factory.set_class("root.class")
local option_class_owner = reactive.factory({ class_name = "option.class" })
local interval_option_owner = reactive.factory({ interval_time = 0.9 })
assert(root.name == nil, "factory owner should not expose built-in name directly")
assert(root.parent == nil, "factory owner should not expose built-in parent directly")
assert(root.full_name == nil, "factory owner should not expose built-in full_name directly")
assert(root.delete == nil, "factory owner should not expose built-in delete directly")
assert_same(root.factory.name(), "root", "factory should expose built-in name")
assert_same(root.factory.parent(), nil, "factory should expose built-in parent")
assert_same(root.factory.full_name(), "root", "factory should expose built-in full_name")
assert(type(root.factory.delete.add) == "function", "factory should expose built-in delete scope")
assert(root.factory.timer.interval_time == interval_option_owner.factory.timer.interval_time, "factory timer interval should be shared")
assert_same(interval_option_owner.factory.timer.interval_time(), 0.05, "factory options should not override shared timer interval")
root.factory.ref_field("score", 1)
root.factory.ref_field("level", 2)
root.factory.collection_field("tags", { prevent_duplicate = true })
root.factory.field("child").child()
root.child.factory.ref_field("label", "x")
root.factory.event_field("ready")
assert(root.score ~= nil, "factory field builder should assign created ref to owner")
assert_same(root.level(), 2, "factory ref_field should assign created ref to owner")
root.tags.add("boss")
assert_same(root.tags().first(), "boss", "factory collection_field should assign created collection to owner")
assert_same(root.class_name, "root.class", "factory set_class should assign owner class")
assert_same(option_class_owner.class_name, "option.class", "factory options should assign owner class")
assert(root.factory.is_instance_of(root, "root.class"), "factory is_instance_of should check owner class")
assert(root.child ~= nil, "factory field builder should assign created child to owner")
assert(root.ready ~= nil, "factory field builder should assign created event to owner")
local timer_runs = 0
local root_timer = root.factory.timer(function(interval_time)
    timer_runs = timer_runs + interval_time
end)
assert_same(timer_registered[#timer_registered].interval_time, 0.05, "factory timer should use injected default interval")
timer_registered[#timer_registered].trigger()
assert_same(timer_runs, 0.05, "factory timer should run through injected trigger")
assert_same(timer_triggered, 1, "timer driver trigger hook should wrap action")

local stop_scope = root.factory.create_scope({ name = "stop_scope" })
local scoped_timer = root.factory.timer(function()
    timer_runs = timer_runs + 1
end, 0.1, stop_scope)
assert_same(scoped_timer.get_interval_time(), 0.1, "factory timer should accept explicit interval")
stop_scope.dispose()
assert(scoped_timer.is_disposed(), "delete scope should dispose mounted timer")
assert_same(timer_destroyed, 1, "delete scope should destroy mounted timer once")

assert_same(root.score.get_name(), "root.score", "factory should assign child model names")
assert_same(root.child.factory.get_full_name(), "root.child", "factory child should inherit parent name")
root.factory.dispose()
assert(root.score.is_disposed(), "factory dispose should dispose captured refs")
assert(root.child.factory.is_disposed(), "factory dispose should dispose child factories")
assert(root_timer.is_disposed(), "factory dispose should dispose created timers")
assert_same(timer_destroyed, 2, "factory dispose should destroy remaining timers once")

local parent_for_children = reactive.factory({ name = "parent_for_children" })
local child_a = reactive.factory({ name = "child_a" })
local child_b = reactive.factory({ name = "child_b" })
parent_for_children.factory.add_children({ child_a.factory, child_b.factory })
assert_same(child_a.factory.get_parent(), parent_for_children.factory, "factory add_children should attach first child factory")
assert_same(child_b.factory.get_parent(), parent_for_children.factory, "factory add_children should attach second child factory")
parent_for_children.factory.dispose()

local ui_parent = reactive.factory({ name = "ui_parent" })
local ui_child = reactive.factory({ name = "ui_child" })
local non_ui_owner = reactive.factory({ name = "non_ui_owner" })
ui_parent.factory.set_class("ui")
ui_child.factory.set_class("ui")
non_ui_owner.factory.set_class("addon")
ui_parent.handle = reactive.ref("ui_parent_handle")
ui_child.handle = reactive.ref("ui_child_handle")
ui_parent.child = ui_child
assert_same(ui_child.factory.get_parent(), nil, "capturing a ui child should not attach parent")
ui_parent.factory.add_child(ui_child.factory)
assert_same(ui_child.factory.get_parent(), ui_parent.factory, "ui add_child should attach ui child factory")
non_ui_owner.child = ui_child
assert_same(ui_child.factory.get_parent(), ui_parent.factory, "non-ui capture should not steal captured ui parent")
non_ui_owner.factory.add_child(ui_child.factory)
assert_same(ui_child.factory.get_parent(), non_ui_owner.factory, "add_child should attach explicit child factory")
ui_parent.factory.dispose()
non_ui_owner.factory.dispose()

local loop_registered
local loop_destroyed = 0
reactive.set_factory_timer_loop(function(trigger, interval_time)
    loop_registered = {
        trigger = trigger,
        interval_time = interval_time,
    }
    return function()
        loop_destroyed = loop_destroyed + 1
    end
end, 0.2)
local compat_timer = reactive.timer({
    action = function()
        timer_runs = timer_runs + 1
    end,
})
assert_same(loop_registered.interval_time, 0.2, "legacy timer loop injection should set default interval")
assert_same(root.factory.timer.interval_time(), 0.2, "factory timer interval should follow global factory timer loop interval")
loop_registered.trigger()
assert_same(timer_runs, 1.05, "legacy timer loop should register trigger")
compat_timer.dispose()
assert_same(loop_destroyed, 1, "legacy timer loop destroy function should be called")

print("reactive test ok")
