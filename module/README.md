# module

模块化运行对象库，用 registry 管理 system、composition 和 addon。

- system 表示可启动、可关闭的运行系统。
- composition 表示 scene 组合根里的装配单元。
- addon 表示可按顺序装配的扩展。

## 设计特性

### 注册表模型

每类模块都有自己的 registry。注册表负责保存定义、按 key 查找，并在需要时创建运行对象。

### 启动顺序

`order` 把模块之间的顺序关系集中处理。系统或扩展需要按依赖顺序装配时，不需要在业务侧手写排序。

### 基础对象

`base` 提供共享生命周期和命名字段。system、composition、addon 在各自语义上复用同一套基础能力。

## 目录

```text
addon.lua      # addon 注册与实例
base.lua       # 模块基础对象
composition.lua # composition 注册与装配
init.lua       # 模块库门面
order.lua      # 顺序处理
system.lua     # system 注册与生命周期
test.lua       # 模块行为测试
```
