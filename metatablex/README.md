# metatablex

metatable 辅助库，用小函数封装 Lua 对象常见元方法。

- 让 table 可以像函数一样调用。
- 统一对象继承、默认索引等元表写法。
- 减少每个模块重复拼装 metatable。

## 设计特性

### 可调用对象

`callable` 把对象和执行函数绑定到 `__call`。工厂表、状态对象和同步对象可以同时保留字段和调用语义。

### 元表收口

库把容易重复的 metatable 模式集中起来。模块只描述自身行为，不在业务文件里反复写元表样板。

## 目录

```text
init.lua  # metatable 辅助函数
test.lua  # 元表行为测试
```
