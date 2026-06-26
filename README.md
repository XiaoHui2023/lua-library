# lua-library

通用 Lua 工具库，供 Y3 地图脚本通过 `script/lib` 加载。当前工程里的 `script/lib` 可以是真实目录，也可以是指向本仓库的 Junction；运行入口只依赖 `script/lib/?.lua` 和 `script/lib/?/init.lua`。

## 模块

```text
callback/    # 事件与 callback API
color/       # 颜色定义、颜色文本渲染
damage/      # 分阶段伤害结算
debugx/      # 调试输出辅助
list/        # 可排序、可遍历、可安全删除的列表结构
mathx/       # 工程增强 math，角度函数使用角度制
metatablex/  # metatable 辅助
module/      # system、blueprint、addon 注册模型
motion/      # 运动数据、修正与渲染分离
point/       # 轻量坐标点结构
reactive/    # 响应式数据辅助
requirex/    # 相对 require 与开发期单模块重载
state_machine/ # 层级状态机
stringx/     # 工程增强 string
tablex/      # table 工具函数
template/    # 字符串模板渲染
```

每个模块目录都有自己的 `README.md`。根 README 只做索引与加载说明，模块级用法、目录和设计特性写在对应模块目录内。

## 加载

运行入口按 `main.lua` 所在目录拼出 `lib` 搜索路径：

```lua
local main_source = debug.getinfo(1, "S").source
local script_root = main_source:sub(1, 1) == "@" and main_source:sub(2) or main_source
script_root = script_root:match("^(.*)[/\\][^/\\]+$") or "."
package.path = script_root .. "/lib/?.lua;" .. script_root .. "/lib/?/init.lua;" .. package.path
```

这避免把本机 `D:/Project/lua/lua-library` 或超长相对路径写进业务脚本。

## requirex

`requirex.reload(require)` 返回一个包装后的 `require`：

- 普通模块名保持原样，例如 `require "mathx"`。
- 以 `.` 开头的模块名按调用者文件位置解析，例如 `require ".child"`。
- 普通模式使用 Lua 自带 `package.loaded` 缓存。
- `hot_reload = true` 时只清理本次解析出的目标模块，不递归清理子依赖，也不迁移外部已保存的旧对象。

## mathx

`mathx` 会扩展全局 `math` 表，这是当前工程约定。角度相关函数使用角度制：

- `math.sin(90)` 返回 `1`。
- `math.atan(y, x)` 返回角度。
- `math.sin_radian`、`math.cos_radian`、`math.asin_radian`、`math.atan_radian` 保留弧度入口。
- `math.raw` 暴露 Lua 原生函数，例如 `math.raw.sin(math.raw.pi / 2)`。

后端通过 `mathx.set_backend` 注入。递归保护会在后端内部调用 `math.sin` 等函数时退回原生 Lua 函数，避免后端实现被全局覆盖再次绕回自己。

## 测试

可直接运行单模块测试：

```powershell
lua lib\requirex\test.lua
lua lib\mathx\test.lua
lua lib\metatablex\test.lua
lua lib\stringx\test.lua
lua lib\template\test.lua
```

测试脚本会自行把库根目录加入 `package.path`。
