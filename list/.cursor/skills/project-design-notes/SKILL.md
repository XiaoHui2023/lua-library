---
name: project-design-notes
description: list 子库：Agent 当前有效的设计意图与硬性要求；变更见 project-changelog。
---

# 设计笔记（当前有效）

> 变更记录见 `list/.cursor/skills/project-changelog/SKILL.md`；矛盾以 changelog 最新条目为准。Monorepo 级约定见根 `.cursor/skills/project-design-notes/SKILL.md`。

## 设计意图

list 工具子库：带顺序、可删除、可遍历的列表结构；依赖 `ordered_map` 子库的元表辅助。

## 硬性要求

- 本库 Agent 引导仅保留三件套；通用规范在 `~/.cursor/skills/`。
- 用户向说明写在 `list/README.md`；设计口径不写进源码长注释。
- 加载时显式 `require "lib.ordered_map"`，不依赖 Y3 或游戏脚本目录。

## 备忘与待定

- 测试脚本待后续决议。
