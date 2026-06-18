local M = {}

---@param context? lib.damage.context 单次伤害结算上下文
---@return lib.damage.context
local function normalize_context(context)
    context = context or {}
    local damage = context.damage or context.base_damage or 0
    context.damage = damage
    context.base_damage = context.base_damage or damage
    context.has_control = context.has_control or context.has_cc or false
    context.has_cc = context.has_control
    context.tags = context.tags or {}
    context.data = context.data or {}
    return context
end

---@param context lib.damage.context
---@return lib.damage.state
local function create_state(context)
    return {
        context = context,
        base_damage = context.base_damage or 0,
        damage = context.damage or 0,
        hit = true,
        evaded = false,
        damage_immune = false,
        control_immune = false,
        has_damage = false,
        has_control = context.has_control or false,
        stopped = false,
        stop_reason = nil,
        source = context.source,
        target = context.target,
        applied_modifiers = {},
    }
end

---@param state lib.damage.state
---@return lib.damage.result
local function build_result(state)
    local final_damage = state.damage
    if state.damage_immune or not state.hit then
        final_damage = 0
    end
    if final_damage < 0 then
        final_damage = 0
    end

    return {
        damage = final_damage,
        hit = state.hit,
        evaded = state.evaded,
        has_damage = state.hit and not state.damage_immune and final_damage > 0,
        has_control = state.hit and state.has_control and not state.control_immune,
        damage_immune = state.damage_immune,
        control_immune = state.control_immune,
        source = state.source,
        target = state.target,
        context = state.context,
        applied_modifiers = state.applied_modifiers,
    }
end

---@param self lib.damage
---@param state lib.damage.state
local function run_damage_resolution(self, state)
    self.on_prepare.run(state)
    self.prepare.run(state, state)

    state.evaded = self.target.evasion.run(state, false)
    state.hit = not state.evaded
    if not state.hit then
        self.on_miss.run(state)
        return
    end
    self.on_hit.run(state)

    state.damage_immune = self.target.damage_immunity.run(state, false)
    if state.damage_immune then
        self.on_damage_immunity.run(state)
        return
    end

    local source_fixed = self.source.fixed.run(state, nil)
    if source_fixed ~= nil then
        state.damage = source_fixed
        self.on_damage_changed.run(state)
    else
        local target_fixed = self.target.fixed.run(state, nil)
        if target_fixed ~= nil then
            state.damage = target_fixed
            self.on_damage_changed.run(state)
        else
            state.damage = self.source.flat.run(state, state.damage)
            state.damage = self.source.percent.run(state, state.damage)
            state.damage = self.target.percent.run(state, state.damage)
            state.damage = self.target.flat.run(state, state.damage)
        end
    end

    state.damage_immune = self.target.final.run(state, false)
    if state.damage_immune then
        self.on_final_immunity.run(state)
    end

    if state.has_control then
        state.control_immune = self.target.control_immunity.run(state, false)
        if state.control_immune then
            self.on_control_immunity.run(state)
        end
    end
end

---@param self lib.damage
---@param context? lib.damage.context 单次伤害结算上下文
---@return lib.damage.result
function M.resolve(self, context)
    local state = create_state(normalize_context(context))
    self.on_start.run(state)
    run_damage_resolution(self, state)
    local result = build_result(state)
    self.on_finish.run(result, state)
    return result
end

return M
