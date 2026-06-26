# damage

可组合伤害结算库，把命中、免疫、加成、减免和最终结算拆成有序阶段。

- 伤害流程由阶段驱动，modifier 可以按阶段挂载。
- source / target 两侧分别承载攻击方与受击方修正。
- 结算结果保留应用过的 modifier，方便调试和战报展示。

## 设计特性

### 阶段结算

伤害从准备阶段进入命中、固定值、百分比、免疫和最终阶段。每个阶段只处理自己的修正规则，减少大型结算函数里的条件堆叠。

### 双侧修正

攻击方和受击方各有独立阶段组。攻击方常放增伤、系数、固定值；受击方常放闪避、减伤、免疫和最终修正。

### 生命周期

伤害器基于 reactive factory 创建，事件和阶段随对象一起释放。临时 modifier 可以设置使用次数或使用后移除。

## 目录

```text
constants.lua  # 阶段名与共享常量
effect.lua     # 便捷效果挂载
init.lua       # 伤害器门面与阶段组装
modifier.lua   # modifier 规则
phase.lua      # 单个阶段执行模型
resolver.lua   # 一次伤害结算流程
side.lua       # source / target 阶段组合
test.lua       # 伤害结算测试
```

## API

| 名称 | 用途 |
| --- | --- |
| `create` | 创建伤害器 |
| `phase` | 创建独立结算阶段 |
| `modifier_phase` | `phase` 的语义别名 |
| `PHASE` | 标准阶段名集合 |
