---
name: project-design-notes
description: 本仓库：Agent 当前有效的设计意图与硬性要求；变更见 project-changelog。
---

# 设计笔记（当前有效）

> 变更记录见 `.cursor/skills/project-changelog/SKILL.md`；矛盾以 changelog 最新条目为准。

## 设计意图

Lua 工具与模块库：提供可复用的 Lua 模块，供脚本与宿主环境引用。

## 硬性要求

- 项目内 Agent 引导仅保留三件套（预加载、设计笔记、changelog）；通用规范放在 `~/.cursor/skills/`。
- 用户向文档分工：根 `README.md` 写用途与用法；设计口径不写进源码长注释。

## 备忘与待定

- 模块目录布局、包管理与测试方式待后续决议。
