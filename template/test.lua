local source = debug.getinfo(1, "S").source
local template_dir = source:sub(1, 1) == "@" and source:sub(2) or source
template_dir = template_dir:match("^(.*)[/\\][^/\\]+$") or "."
local library_root = template_dir:match("^(.*)[/\\][^/\\]+$") or template_dir
local project_root = library_root:match("^(.*)[/\\][^/\\]+$") or library_root
package.path = project_root .. "/?.lua;" .. project_root .. "/?/init.lua;" .. library_root .. "/?.lua;" .. library_root .. "/?/init.lua;" .. package.path

local template = require "lib.template"
local tablex = require "lib.tablex"

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_eq") .. ": got " .. tostring(actual) .. ", want " .. tostring(expected))
    end
end

local function assert_list(actual, expected, message)
    assert_eq(#actual, #expected, (message or "assert_list") .. " length")
    for index, value in ipairs(expected) do
        assert_eq(actual[index], value, (message or "assert_list") .. " item " .. index)
    end
end

local function create_context(name, entries)
    local fields = {}
    for key in pairs(entries) do
        fields[#fields + 1] = key
    end
    table.sort(fields)

    return {
        name = function()
            return name
        end,
        find = function(placeholder)
            local entry = entries[placeholder]
            if entry == nil then
                return nil
            end
            return tablex.clone(entry)
        end,
        get_prop_fields = function()
            return fields
        end,
    }
end

local function create_renderer(entries)
    return template.create_template_renderer({
        exposed_contexts = {
            create_context("test", entries),
        },
    })
end

local renderer = create_renderer({
    name = { value = "Footman" },
    damage = { value = 12 },
})
assert_eq(renderer("Unit {name}, damage {damage}."), "Unit Footman, damage 12.", "renderer should replace values")
assert_eq(renderer("Unknown {missing}."), "Unknown {missing}.", "renderer should keep unknown placeholders")

local staged = create_renderer({
    text = { value = "base" },
})
staged.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "format",
    on_render = function(entry)
        entry.value = entry.value .. ":format"
    end,
}))
staged.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "locale",
    on_render = function(entry)
        entry.value = entry.value .. ":locale"
    end,
}))
staged.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "coloring",
    on_render = function(entry)
        entry.value = entry.value .. ":coloring"
    end,
}))
assert_eq(staged("{text}"), "base:format:locale:coloring", "renderer should run token stages in fixed order")

local prioritized = create_renderer({
    text = { value = "" },
})
prioritized.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "format",
    priority = 10,
    on_render = function(entry)
        entry.value = entry.value .. "A"
    end,
}))
prioritized.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "format",
    priority = -1,
    on_render = function(entry)
        entry.value = entry.value .. "B"
    end,
}))
assert_eq(prioritized("{text}"), "BA", "renderer should sort stage handlers by priority")

local list_renderer = create_renderer({
    numbers = { values = { 1, 2, 3 } },
})
list_renderer.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "format",
    on_render = function(entry)
        entry.value = "#" .. entry.value
    end,
}))
assert_eq(list_renderer("{numbers}"), "#1#2#3", "renderer should render list tokens before default join")

list_renderer.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "join",
    priority = -1,
    on_render = function(entry)
        entry.value = table.concat(entry.values, ",")
    end,
}))
list_renderer.placeholder_renderers.add(template.create_placeholder_renderer({
    stage = "join",
    priority = 10,
    on_render = function(entry)
        entry.value = "unused"
    end,
}))
assert_eq(list_renderer("{numbers}"), "#1,#2,#3", "renderer should use the first join handler only")

local old_context = create_context("ctx", {
    name = { value = "old" },
})
local new_context = create_context("ctx", {
    name = { value = "new" },
})
local reversed = template.create_template_renderer({
    exposed_contexts = {
        old_context,
        new_context,
    },
})
assert_eq(reversed("{name}"), "new", "renderer should search newer exposed contexts first")
assert_list(reversed.get_exposed_fields(), { "ctx:name", "ctx:name" }, "renderer should expose field names")

local table_renderer = template.create_template_renderer({
    exposed_contexts = {
        {
            name = "Rifleman",
            damage = 18,
        },
    },
})
assert_eq(table_renderer("{name}:{damage}"), "Rifleman:18", "renderer should read plain table contexts")
assert_list(table_renderer.get_exposed_fields(), { ":damage", ":name" }, "plain table context should expose table keys")

local custom_reader = template.create_template_renderer({
    exposed_contexts = {
        {
            name = "Mage",
            stats = {
                damage = 7,
            },
        },
    },
    value_reader = function(input, placeholder)
        if placeholder == "damage" then
            return true, input.stats.damage * 2
        end
        return input[placeholder] ~= nil, input[placeholder]
    end,
})
assert_eq(custom_reader("{name}:{damage}"), "Mage:14", "renderer should support injected table value reader")

local default_reader = template.get_default_value_reader()
template.set_default_value_reader(function(input, placeholder)
    if placeholder == "upper_name" then
        return true, string.upper(input.name)
    end
    return default_reader(input, placeholder)
end)
local default_injected = template.create_template_renderer({
    exposed_contexts = {
        {
            name = "caster",
        },
    },
})
assert_eq(default_injected("{upper_name}"), "CASTER", "renderer should support injected default table value reader")
template.set_default_value_reader(default_reader)

local ok = pcall(template.create_placeholder_renderer, {
    stage = "missing",
    on_render = function() end,
})
assert(not ok, "placeholder renderer should reject invalid stages")

local removable = create_renderer({
    text = { value = "" },
})
local shared_renderer = template.create_placeholder_renderer({
    stage = "format",
    on_render = function(entry)
        entry.value = entry.value .. "x"
    end,
})
local remove_first = removable.placeholder_renderers.add(shared_renderer)
local remove_second = removable.placeholder_renderers.add(shared_renderer)
remove_second()
assert_eq(removable("{text}"), "x", "collection remove handle should remove the matching add only")
remove_first()
assert_eq(removable("{text}"), "", "collection remove handle should support duplicate items")

ok = pcall(function()
    shared_renderer.stage.set("missing")
end)
assert(not ok, "placeholder renderer stage ref should reject invalid stages")

ok = pcall(function()
    shared_renderer.priority.set("high")
end)
assert(not ok, "placeholder renderer priority ref should reject non-number values")

ok = pcall(renderer, 1)
assert(not ok, "renderer should reject non-string templates")

print("template test ok")
