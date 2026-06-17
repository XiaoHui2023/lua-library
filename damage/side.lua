local constants = require "lib.damage.constants"
local create_phase = require "lib.damage.phase"

local M = {}

---@return lib.damage.source_side
function M.create_source()
    ---@class lib.damage.source_side
    local o = {}
    o.fixed = create_phase(constants.PHASE.SOURCE_FIXED, "first")
    o.flat = create_phase(constants.PHASE.SOURCE_FLAT, "chain")
    o.percent = create_phase(constants.PHASE.SOURCE_PERCENT, "chain")
    o.percentage = o.percent
    return o
end

---@return lib.damage.target_side
function M.create_target()
    ---@class lib.damage.target_side
    local o = {}
    o.evasion = create_phase(constants.PHASE.HIT, "or")
    o.fixed = create_phase(constants.PHASE.TARGET_FIXED, "first")
    o.percent = create_phase(constants.PHASE.TARGET_PERCENT, "chain")
    o.percentage = o.percent
    o.flat = create_phase(constants.PHASE.TARGET_FLAT, "chain")
    o.final = create_phase(constants.PHASE.FINAL, "or")
    o.damage_immunity = create_phase(constants.PHASE.DAMAGE_IMMUNITY, "or")
    o.control_immunity = create_phase(constants.PHASE.CONTROL, "or")
    o.cc_immunity = o.control_immunity
    return o
end

---@param owner lib.damage
---@param side table
function M.mount_delete(owner, side)
    local mounted = {}
    for _, phase in pairs(side) do
        if type(phase) == "table" and phase.delete ~= nil and not mounted[phase] then
            mounted[phase] = true
            owner.delete.mount(phase.delete)
        end
    end
end

return M
