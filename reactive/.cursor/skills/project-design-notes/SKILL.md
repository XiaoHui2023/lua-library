---
name: project-design-notes
description: reactive_model 子库：Agent 当前有效的设计意图与硬性要求；变更见 project-changelog。
---

# 设计笔记（当前有效）

> 变更记录见 `reactive_model/.cursor/skills/project-changelog/SKILL.md`；矛盾以 changelog 最新条目为准。Monorepo 级约定见根 `.cursor/skills/project-design-notes/SKILL.md`。

## 设计意图

响应式数据模型子库，替代 `script/utils/hook` 中的响应式能力：以 **ref-model** 为基础，提供普通值、列表、字典、计算值与事件，并由 factory 统一管理创建与销毁。

## 模块

```text
reactive_model/
  init.lua
  event.lua
  track.lua
  reactive_model.lua
  ref_model.lua
  list_ref_model.lua
  table_ref_model.lua
  computed_model.lua
  factory.lua
```

## 硬性要求

- 所有对象例化时只接收一个 `table` 参数。
- 基础可变数据由 `reactive_model` 承载版本号；读取时 `track`，变更时 `touch`。
- `list_ref_model` 与 `table_ref_model` 为 ref 扩展，内部修改也递增版本。
- `computed_model` 惰性计算，依赖版本变化后才重新计算；循环依赖直接报错并带上模型名。
- 事件支持 `always` / `once`；订阅返回可重复调用无害的删除函数。
- factory 创建的对象挂到 factory 的 `dispose`；factory 销毁时级联清理子模型与子 factory。
- 用户向说明写在 `reactive_model/README.md`；设计口径不写进源码长注释。

## 与 hook 迁移

| hook | reactive_model |
| --- | --- |
| `set` | `ref` |
| `add` | `list` |
| `map` | `table` |
| `computed` | `computed` |
| `event` / `once_event` | `event` / `once_event` |
| `factory` | `factory` |

`hook.semaphore` 不在本库范围。
