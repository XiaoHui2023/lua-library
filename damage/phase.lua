---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.reactive
local reactive = require "lib.reactive"
local damage_modifier = require "lib.damage.modifier"

---@param phase string
---@param mode lib.damage.modifier_mode
---@return lib.damage.phase
return function(phase, mode)
    ---@class lib.damage.phase: lib.reactive.factory
    local o = reactive.factory({ name = phase })
    o.set_class("lib.damage.phase")

    o.phase = phase
    o.mode = mode

    ---@type lib.reactive.add<lib.damage.modifier>
    o.modifiers = reactive.collection({
        compare = function(a, b)
            return a.priority < b.priority
        end,
    })
    o.modifiers.wrap_add(damage_modifier.normalize)

    ---@type lib.reactive.event<lib.damage.applied_modifier>
    o.on_modify = o.factory.event({ name = "on_modify" })

    ---@type lib.reactive.event<any>
    o.on_run = o.factory.event({ name = "on_run" })

    o.last_value = nil

    ---@param modifier lib.damage.modifier
    ---@return fun()
    function o.add_modifier(modifier)
        local normalized = damage_modifier.normalize(modifier)
        local remove_from_collection = o.modifiers.add(normalized)
        local unbind_owner = damage_modifier.bind_owner_delete(normalized.owner, remove_from_collection)
        local removed = false

        local remove = function()
            if removed then
                return
            end
            removed = true
            unbind_owner()
            remove_from_collection()
        end

        normalized.delete = remove
        return remove
    end

    o.add = o.add_modifier

    ---@param state lib.damage.state
    ---@param initial any
    ---@return any
    function o.run(state, initial)
        local value = damage_modifier.default_value(mode, initial)

        o.modifiers.get().for_each(
            ---@param modifier lib.damage.modifier
            ---@param iter lib.list.for_each.context
            function(modifier, iter)
                if not damage_modifier.can_use(modifier) then
                    return
                end
                if modifier.condition ~= nil and not modifier.condition(state, modifier) then
                    return
                end

                local before = value
                local after = modifier.callback(state, value, modifier)
                if after == nil then
                    return
                end

                damage_modifier.assert_value(after, mode)

                if damage_modifier.should_apply_value(value, after, mode) then
                    value = after
                end

                local applied = {
                    phase = phase,
                    modifier = modifier,
                    before = before,
                    after = value,
                }
                state.applied_modifiers[#state.applied_modifiers + 1] = applied
                o.on_modify.run(applied)

                if modifier.uses ~= nil then
                    modifier.uses = modifier.uses - 1
                    if modifier.uses <= 0 then
                        iter.remove()
                    end
                elseif modifier.remove_after_use then
                    iter.remove()
                end

                if damage_modifier.should_stop(mode, value) then
                    iter.stop()
                end
            end
        )

        o.last_value = value
        o.on_run.run(value, state)
        return value
    end

    metatablex.callable(o, o.run)

    return o
end
