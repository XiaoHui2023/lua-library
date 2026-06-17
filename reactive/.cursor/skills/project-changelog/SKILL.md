---
name: project-changelog
description: reactive_model 子库：按时间记录要求与决议；最新在上；矛盾以最新为准。
---

# 变更记录

（规则见 `~/.cursor/skills/agent-project-changelog/SKILL.md`。）

## 2026-06-09

- **决议**：按设计文档实现 reactive_model 全模块（reactive_model、ref、list、table、computed、event、track、factory）。
- **决议**：依赖失效判断改为模型 `version` 比较，替代 hook 的脏标记传播。
- **决议**：`hook.semaphore` 不纳入本库；其余 hook 类型一一对应迁移表见 design-notes。

## 2026-06-09（早前）

- **决议**：作为 lua-library 首个子库，例化库级 Agent 三件套。
