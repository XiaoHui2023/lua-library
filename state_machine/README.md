# state_machine

层级状态机库，用 state、machine、transition、guard 和 action 组织玩法流程。

- 状态可以拥有子状态和生命周期回调。
- transition 描述状态之间的跳转。
- machine 负责事件分发和拥有者级清理。

## 设计特性

### 状态对象

状态保存 entry、exit、done、timer、children 等行为。它既可以单独启动，也可以作为父状态下的子流程。

### 层级编排

`build_tree` 从嵌套 table 构造状态树，`sequence` 快速创建顺序状态链。阻挡、反击、投射物阶段等流程可以保持结构化。

### 模板扩展

`register_template` 注册常用状态生成器。复杂项目可以把标准状态片段做成模板，再由配置树引用。

## 目录

```text
init.lua     # 状态机门面、sequence 与状态树构造
machine.lua  # machine 事件和拥有者管理
state.lua    # state 生命周期、跳转和子状态
test.lua     # 状态机测试
```
