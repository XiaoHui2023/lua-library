# reactive

`reactive.factory` 用来创建带生命周期管理的对象。对象本身持有 `factory` 字段，所有通过 factory 创建的 reactive 字段都会被 factory 捕获，随对象一起命名和释放。

## factory 字段创建

推荐直接通过 `o.factory.<field>` 创建对象字段：

```lua
local o = reactive.factory({ name = "player" })

o.factory.hero.set(nil)
o.factory.on_exit.event()
o.factory.is_human.computed(function()
    return o.controller() == "user"
end)
o.factory.skills.add()
```

上面的写法会由库自动赋值到对象自身，等价于创建后得到：

```lua
o.hero
o.on_exit
o.is_human
o.skills
```

字段名来自 `factory.<field>`，所以通常不需要再传 `name`。factory 会在创建时把字段挂到 owner 上，再走统一的捕获逻辑，补齐完整名称、父子关系和 dispose 绑定。

如果字段名和 factory 自身方法重名，使用 `field` 明确指定字段名：

```lua
o.factory.field("child").child()
```

旧写法仍可工作，但不再推荐：

```lua
o.hero = o.factory.set(nil)
```

## 不再手动刷新字段

字段创建和赋值已经由 factory 内部完成，不需要在对象初始化末尾调用刷新函数。

不要再写：

```lua
o.factory.register_hook_fields()
```

如果字段名称、父对象名称发生变化，factory 内部会自动刷新已有子字段名称。

## 保留返回值的场景

局部临时 reactive 对象可以继续接收返回值，只要不需要作为对象字段暴露即可：

```lua
local once_end = o.factory.once_event()
local render_size = o.factory.computed(function()
    return o.width() * o.height()
end)
```

需要作为对象字段时，优先使用 `o.factory.<field>` 写法。
