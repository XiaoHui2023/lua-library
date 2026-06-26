# callback

轻量回调与声明式 API 库，用来把“谁声明能力”和“谁处理能力”分开。

- 支持普通事件、一次性事件和 replay 事件。
- API 实例携带字段值，handler 读取同一个 payload。
- 可配置错误处理与严格模式，便于测试中暴露失败。

## 设计特性

### 事件模型

事件保存订阅函数，触发时顺序调用。订阅返回取消函数，运行中取消会延后压缩列表，避免遍历时破坏顺序。

### API 声明

`api` 是带名字的事件包装。声明方只暴露 API 对象，处理方注册 handler，调用方用 table 创建一次 payload 并触发。

### 错误策略

默认错误会交给错误处理函数或 `print`。严格模式下，handler 报错会继续走错误上报，再把错误抛出给调用者。

## 目录

```text
init.lua  # 事件、一次性事件、api 与错误策略
test.lua  # 回调行为测试
```

## API

| 名称 | 用途 |
| --- | --- |
| `event` | 创建可多次触发的事件 |
| `once_event` | 创建只消费一次的事件 |
| `api` | 创建带 payload 的 callback API |
| `set_event_error_handler` | 注入统一错误处理 |
| `set_strict` | 开关严格错误模式 |
| `is_strict` | 查询严格错误模式 |
