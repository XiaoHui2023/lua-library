# mathx

工程增强 math 库，统一角度制三角函数、随机后端和几何辅助。

- `mathx` 会扩展全局 `math`，角度函数默认使用角度制。
- 原生弧度函数保留在 `math.raw` 和 `*_radian` 入口。
- 几何子目录提供点、圆、矩形、多边形等计算对象。

## 设计特性

### 角度制入口

游戏脚本多数朝向、扇形和旋转都用角度表达。库把常用三角函数调整为角度制，减少每处手写弧度转换。

### 后端保护

运行时可注入随机数和三角函数后端。后端内部再调用 `math.sin` 等函数时，会退回原生函数，避免递归绕回增强入口。

### 几何对象

`geometry/` 放通用几何计算。命中范围、区域判断和 UI 边界计算可以复用这些基础对象。

## 目录

```text
init.lua             # math 增强入口与后端注入
geometry/base.lua    # 几何对象共享基础
geometry/circle.lua  # 圆形
geometry/point.lua   # 点
geometry/polygon.lua # 多边形
geometry/rectangle.lua # 矩形
test.lua             # 数学与几何测试
```
