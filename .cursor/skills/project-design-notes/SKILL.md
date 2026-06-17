---
name: project-design-notes
description: 本仓库：Agent 当前有效的设计意图与硬性要求；变更见 project-changelog。
---

# 设计笔记（当前有效）

> 变更记录见 `.cursor/skills/project-changelog/SKILL.md`；矛盾以 changelog 最新条目为准。

## 设计意图

Lua 工具与模块库（monorepo）：根仓库统筹多个**独立子库**；每个子目录是一个可单独引用的 Lua 库，提供可复用模块供脚本与宿主环境引用。

## 仓库布局

| 层级 | 路径示例 | 职责 |
| --- | --- | --- |
| **根仓库** | `lua-library/` | monorepo 统筹、跨库约定、根 `README.md` |
| **子库** | `math/`、`string/` 等 | 单个库的源码、库级 `README`、库级 Agent 三件套 |

新增子库：在根下建同名目录，并**同步例化**库内 `.cursor/skills/` 三件套（见下节）。

## 硬性要求

- **根仓库**与**每个子库**各自保留 Agent 三件套（预加载、设计笔记、changelog）；通用规范放在 `~/.cursor/skills/`，不在库内复制同伴规范。
- **子库也是「仓库」**：子库目录内须有自己的 `.cursor/skills/`，结构与根仓库相同；库级 design-notes 写该库的意图与硬性要求，根 design-notes 写 monorepo 级约定。
- 在某一子库内做实质性工作时：经**该子库**预加载 skill 加载库级 design-notes 与 changelog；并 Read 根 `project-design-notes`（monorepo 口径）。
- 用户向文档分工：根 `README.md` 写 monorepo 用途与索引；各子库 `README.md` 写该库用法；设计口径不写进源码长注释。

## 备忘与待定

- 子库目录命名、包管理与测试方式待后续决议。
- 当前子库（均已例化库级三件套）：`color/`（已含 `color.lua`）、`math/`、`string/`、`ordered_map/`、`reactive_model/`。
