---
name: project-changelog
description: 本仓库：按时间记录要求与决议；最新在上；矛盾以最新为准。
---

# 变更记录

（规则见 `~/.cursor/skills/agent-project-changelog/SKILL.md`。）

## 2026-06-09

- **决议**：子库 `table/` 重命名为 `ordered_map/`；加载路径改为 `require "lib.ordered_map"`。
- **决议**：`ordered_map/`、`list/` 子库从 OutOfDungeon `script/utils` 迁入。
- **决议**：`color/` 子库完成首版迁移：`color.lua`、`README.md`、`test.lua`；通用逻辑从 OutOfDungeon 游戏脚本迁入。
- **决议**：新增子库 `color/`、`list/`、`math/`、`string/`、`ordered_map/`，各例化库级 Agent 三件套。
- **决议**：本仓库为 monorepo；根下每个子目录是一个独立子库（如 `reactive_model/`）。
- **要求**：每个子库目录内须例化 Agent 三件套（`.cursor/skills/` 下预加载、设计笔记、changelog），与根仓库结构相同；在子库内工作时经该子库预加载加载库级 design-notes 与 changelog。
- **决议**：仓库按 Agent 三件套初始化；远程仓库为 `https://github.com/XiaoHui2023/lua-library`。
- **要求**：实质性工作前经 `project-preload-skills` 加载 design-notes 与 changelog。
