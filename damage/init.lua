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
---@field damage? number 当前伤害值；省略时使用 base_damage 或 0
---@field base_damage? number 初始基础伤害；省略时使用 damage
---@field source? any 伤害来源对象
---@field target? any 伤害目标对象
---@field has_control? boolean 是否附带控制效果
---@field has_cc? boolean has_control 的兼容别名
---@field tags? table<string, boolean> 伤害标签集合
---@field data? table 调用方附加数据

---@class lib.damage.state
---@field context lib.damage.context 原始伤害上下文
---@field base_damage number 基础伤害值
---@field damage number 当前伤害值
---@field hit boolean 是否命中
---@field evaded boolean 是否被闪避
---@field damage_immune boolean 是否伤害免疫
---@field control_immune boolean 是否控制免疫
---@field has_damage boolean 是否造成有效伤害
---@field has_control boolean 是否包含有效控制
---@field stopped boolean 结算是否已停止
---@field stop_reason? string 停止结算的原因
---@field source? any 伤害来源对象
---@field target? any 伤害目标对象
---@field applied_modifiers lib.damage.applied_modifier[] 已生效的修正器记录

---@class lib.damage.result
---@field damage number 当前伤害值
---@field hit boolean 是否命中
---@field evaded boolean 是否被闪避
---@field has_damage boolean 是否造成有效伤害
---@field has_control boolean 是否包含有效控制
---@field damage_immune boolean 是否伤害免疫
---@field control_immune boolean 是否控制免疫
---@field source? any 伤害来源对象
---@field target? any 伤害目标对象
---@field context lib.damage.context 原始伤害上下文
---@field applied_modifiers lib.damage.applied_modifier[] 已生效的修正器记录

---@class lib.damage.modifier
---@field callback fun(state:lib.damage.state,value?:any,modifier?:lib.damage.modifier):any? 修正器执行函数
---@field condition? fun(state:lib.damage.state,modifier:lib.damage.modifier):boolean 修正器生效条件
---@field priority? number 修正器排序优先级
---@field enabled? boolean 修正器是否启用
---@field owner? any 修正器拥有者
---@field source? any 伤害来源对象
---@field name? string 修正器名称
---@field uses? integer 剩余可用次数
---@field remove_after_use? boolean 使用后是否自动移除
---@field delete? fun() 移除该修正器的函数

---@class lib.damage.applied_modifier
---@field phase string 修正器生效的伤害阶段
---@field modifier lib.damage.modifier 已执行的修正器
---@field before any 执行前的阶段值
---@field after any 执行后的阶段值

---@param args? lib.reactive.factory.options 伤害工厂配置
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

    ---@param context? lib.damage.context 单次伤害结算上下文
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
