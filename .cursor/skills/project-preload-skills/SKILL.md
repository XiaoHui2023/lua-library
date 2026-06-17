---
name: project-preload-skills
description: 本仓库：会话预加载顺序与用过的 skill 记录。
---

# 预加载

## 初始化加载（Session preload）

1. `~/.cursor/skills/project-skill-manifest-policy/SKILL.md`
2. `~/.cursor/skills/doc-surface-roles-zh/SKILL.md`
3. `~/.cursor/skills/forbidden-doc-comment-vocabulary/SKILL.md`
4. `~/.cursor/skills/markdown-authoring-zh/SKILL.md`
5. `.cursor/skills/project-design-notes/SKILL.md`
6. `.cursor/skills/project-changelog/SKILL.md`

## 子库内工作（追加加载）

路径落在某一子库目录（如 `reactive_model/`）时，在根预加载之后 **Read** 该子库的：

1. `<子库>/.cursor/skills/project-preload-skills/SKILL.md`
2. `<子库>/.cursor/skills/project-design-notes/SKILL.md`
3. `<子库>/.cursor/skills/project-changelog/SKILL.md`

## 用过的 skill（追加记录）

- `agent-project-design-notes`
- `agent-project-changelog`
- `project-skill-manifest-policy`
