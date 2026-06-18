---@type lib.tablex
local tablex = require "lib.tablex"
---@type lib.reactive
local reactive = require "lib.reactive"
local damage_modifier = require "lib.damage.modifier"

local M = {}

---@class lib.damage.effect_options
---@field owner? any 效果拥有者，用于跟随拥有者释放
---@field source? any 默认伤害来源
---@field target? any 默认伤害目标
---@field modifiers table<string, lib.damage.modifier|lib.damage.modifier[]>

---@param damage lib.damage
---@param options lib.damage.effect_options
---@return fun()
function M.add(damage, options)
    assert(type(options) == "table", "effect options must be table")
    assert(type(options.modifiers) == "table", "effect modifiers must be table")

    local effect_scope = reactive.scope({ name = "damage_effect" })
    local owner = options.owner
    for phase_name, modifier_list in pairs(options.modifiers) do
        local phase = damage.phase_map[phase_name]
        assert(phase ~= nil, "unknown damage phase: " .. tostring(phase_name))

        if modifier_list.callback ~= nil then
            modifier_list = { modifier_list }
        end

        for _, modifier in ipairs(modifier_list) do
            local entry = tablex.clone(modifier)
            entry.owner = entry.owner or owner
            entry.source = entry.source or options.source
            entry.target = entry.target or options.target
            effect_scope.add(phase.add_modifier(entry))
        end
    end

    local unbind_owner = damage_modifier.bind_owner_delete(owner, effect_scope.dispose)
    effect_scope.add(unbind_owner)

    return function()
        effect_scope.dispose()
    end
end

return M
