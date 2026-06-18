---@type lib.metatablex
local metatablex = require "lib.metatablex"
---@type lib.reactive
local reactive = require "lib.reactive"
local constants = require "lib.damage.constants"
local create_phase = require "lib.damage.phase"
local side = require "lib.damage.side"
local resolver = require "lib.damage.resolver"
local effect = require "lib.damage.effect"

local M = {}

M.PHASE = constants.PHASE
M.phase = create_phase
M.modifier_phase = create_phase

---@alias lib.damage.modifier_mode
---| "chain"
---| "first"
---| "or"
---| "and"
---| "min"
---| "max"

---@class lib.damage.context
---@field damage? number 字段说明
---@field base_damage? number 字段说明
---@field source? any 字段说明
---@field target? any 字段说明
---@field has_control? boolean 字段说明
---@field has_cc? boolean 字段说明
---@field tags? table<string, 字段说明
---@field data? table 字段说明

---@class lib.damage.state
---@field context lib.damage.context
---@field base_damage number
---@field damage number
---@field hit boolean
---@field evaded boolean
---@field damage_immune boolean
---@field control_immune boolean
---@field has_damage boolean
---@field has_control boolean
---@field stopped boolean
---@field stop_reason? string 字段说明
---@field source? any 字段说明
---@field target? any 字段说明
---@field applied_modifiers lib.damage.applied_modifier[]

---@class lib.damage.result
---@field damage number
---@field hit boolean
---@field evaded boolean
---@field has_damage boolean
---@field has_control boolean
---@field damage_immune boolean
---@field control_immune boolean
---@field source? any 字段说明
---@field target? any 字段说明
---@field context lib.damage.context
---@field applied_modifiers lib.damage.applied_modifier[]

---@class lib.damage.modifier
---@field callback fun(state:lib.damage.state,value?:any,modifier?:lib.damage.modifier):any? 字段说明
---@field condition? fun(state:lib.damage.state,modifier:lib.damage.modifier):boolean 字段说明
---@field priority? number 字段说明
---@field enabled? boolean 字段说明
---@field owner? any 字段说明
---@field source? any 字段说明
---@field name? string 字段说明
---@field uses? integer 字段说明
---@field remove_after_use? boolean 字段说明
---@field delete? fun() 字段说明

---@class lib.damage.applied_modifier
---@field phase string
---@field modifier lib.damage.modifier
---@field before any
---@field after any

---@param args? lib.reactive.factory.options 参数说明
---@return lib.damage
function M.create(args)
    ---@class lib.damage: lib.reactive.factory
    ---@operator call(lib.damage.context):lib.damage.result
    local o = reactive.factory(args)
    o.set_class("lib.damage")

    o.prepare = create_phase(M.PHASE.PREPARE, "chain")
    o.source = side.create_source()
    o.target = side.create_target()
    o.attacker = o.source
    o.defender = o.target

    o.phase_map = {
        prepare = o.prepare,
        hit = o.target.evasion,
        evasion = o.target.evasion,
        source_fixed = o.source.fixed,
        target_fixed = o.target.fixed,
        source_flat = o.source.flat,
        source_percent = o.source.percent,
        source_percentage = o.source.percent,
        target_percent = o.target.percent,
        target_percentage = o.target.percent,
        target_flat = o.target.flat,
        damage_immunity = o.target.damage_immunity,
        final = o.target.final,
        control = o.target.control_immunity,
        control_immunity = o.target.control_immunity,
        cc_immunity = o.target.control_immunity,
    }

    o.delete.mount(o.prepare.delete)
    side.mount_delete(o, o.source)
    side.mount_delete(o, o.target)

    o.on_start = o.factory.event({ name = "on_start" })
    o.on_prepare = o.factory.event({ name = "on_prepare" })
    o.on_hit = o.factory.event({ name = "on_hit" })
    o.on_miss = o.factory.event({ name = "on_miss" })
    o.on_damage_changed = o.factory.event({ name = "on_damage_changed" })
    o.on_damage_immunity = o.factory.event({ name = "on_damage_immunity" })
    o.on_final_immunity = o.factory.event({ name = "on_final_immunity" })
    o.on_control_immunity = o.factory.event({ name = "on_control_immunity" })
    o.on_finish = o.factory.event({ name = "on_finish" })

    ---@param phase_name string
    ---@param modifier lib.damage.modifier
    ---@return fun()
    function o.add_modifier(phase_name, modifier)
        local phase = o.phase_map[phase_name]
        assert(phase ~= nil, "unknown damage phase: " .. tostring(phase_name))
        return phase.add_modifier(modifier)
    end

    ---@param options lib.damage.effect_options
    ---@return fun()
    function o.add_effect(options)
        return effect.add(o, options)
    end

    ---@param context? lib.damage.context 参数说明
    ---@return lib.damage.result
    function o.run(context)
        return resolver.resolve(o, context)
    end

    metatablex.callable(o, o.run)
    o.factory.register_hook_fields()

    return o
end

metatablex.callable(M, M.create)

return M
