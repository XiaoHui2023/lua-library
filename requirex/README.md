# requirex

require 包装库，补充相对模块路径和开发期单模块重载能力。

- 普通模块名继续交给 Lua 原生 `require`。
- 以 `.` 开头的模块名按调用文件所在目录解析。
- 热重载只清理当前解析出的目标模块，不递归清理依赖。

## 设计特性

### 相对引用

同目录拆文件时可以写 `require ".child"`，跨父目录可以写点号路径。模块移动后，引用关系更贴近文件结构。

### 局部重载

开发期启用 hot reload 时，只清理本次 require 的目标模块缓存。外部已保存的旧对象不会自动迁移，避免隐藏副作用。

## 目录

```text
init.lua             # require 包装与路径解析
fixture/             # 测试用相对模块
fixture_shared.lua   # 测试共享模块
test.lua             # requirex 行为测试
```
