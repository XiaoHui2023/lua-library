# reactive

Reactive data and lifecycle helpers: `ref`, `event`, `computed`,
`collection`, `scope`, `timer`, and `factory`.

## Factory Field Creation

Factory-created object fields must use explicit field names.

Use `factory.ref_field("field", value)` for ref fields:

```lua
local o = reactive.factory({ name = "player" })

o.factory.ref_field("hero", nil)
```

After creation, the field is available on the owner:

```lua
o.hero()
o.hero.set(unit)
```

Use the explicit `*_field` helpers for other reactive field types:

```lua
o.factory.event_field("on_exit")
o.factory.computed_field("is_human", function()
    return o.controller() == "user"
end)
o.factory.collection_field("skills")
o.factory.field("child").child()
```

Do not use implicit field factory syntax through `factory.<field>.<creator>()`.

The implicit `factory.<field>` entry point is intentionally disabled so
field creation stays visible in code review.

## Anonymous Reactive Values

When a reactive value is only a local temporary and should not become an
object field, create it without a field name:

```lua
local once_end = o.factory.create_once_event()
local render_size = o.factory.create_computed(function()
    return o.width() * o.height()
end)
```

## Files

```text
base.lua        # shared reactive object helpers
collection.lua  # collection change notifications
computed.lua    # derived values
event.lua       # reactive events
factory.lua     # object factory and lifecycle capture
list_ref.lua    # list ref
ref.lua         # value ref
scope.lua       # dispose scope
semaphore.lua   # semaphore
table_ref.lua   # table ref
timer.lua       # timer wrapper
track.lua       # dependency tracking
```
