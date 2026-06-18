local damage = require "lib.damage"
local reactive = require "lib.reactive"

local function assert_damage(result, damage)
    assert(result.damage == damage, string.format("expected damage %s, got %s", damage, result.damage))
end

local damage = damage()

do
    local result = damage({ damage = 10 })
    assert(result.hit)
    assert(result.has_damage)
    assert_damage(result, 10)
end

do
    local remove_flat = damage.source.flat.add_modifier({
        name = "test_source_flat",
        callback = function(_, value)
            return value + 5
        end,
    })
    local remove_percent = damage.source.percent.add_modifier({
        name = "test_source_percent",
        callback = function(_, value)
            return value * 2
        end,
    })
    local remove_armor = damage.target.flat.add_modifier({
        name = "test_target_flat",
        callback = function(_, value)
            return value - 4
        end,
    })

    assert_damage(damage({ damage = 10 }), 26)

    remove_armor()
    remove_percent()
    remove_flat()
end

do
    local shield_item = reactive.scope({ name = "shield_item" })
    damage.add_modifier("damage_immunity", {
        owner = shield_item,
        uses = 1,
        name = "block_once",
        callback = function(state)
            return state.target == "hero"
        end,
    })

    local blocked = damage({ damage = 100, target = "hero" })
    assert_damage(blocked, 0)
    assert(blocked.damage_immune)

    local passed = damage({ damage = 100, target = "hero" })
    assert_damage(passed, 100)
    assert(not passed.damage_immune)
end

do
    local armor_item = reactive.scope({ name = "armor_item" })
    damage.add_effect({
        owner = armor_item,
        modifiers = {
            target_flat = {
                name = "armor_reduce_20",
                callback = function(_, value)
                    return value - 20
                end,
            },
        },
    })

    assert_damage(damage({ damage = 100 }), 80)
    armor_item.dispose()
    assert_damage(damage({ damage = 100 }), 100)
end

do
    local amulet_item = reactive.factory({ name = "amulet_item" })
    damage.add_modifier("source_flat", {
        owner = amulet_item,
        name = "amulet_bonus",
        callback = function(_, value)
            return value + 30
        end,
    })

    assert_damage(damage({ damage = 100 }), 130)
    amulet_item.delete.dispose()
    assert_damage(damage({ damage = 100 }), 100)
end

print("damage_test ok")
