# Refillable Night Equipment Mod

## 功能说明 / Features

### 中文说明

- **暗夜装备可充能**: 暗夜剑可以使用噩梦燃料进行充能
- **充能比例**: 每份噩梦燃料默认恢复20%的耐久度
- **耐久度保留**: 可选择在耐久度耗尽时保留暗夜装备而不是销毁
- **功能管理**: 当耐久度不足时，暗夜装备将失去相应效果（攻击力和理智消耗效果）

### English Description

- **Refillable Night Equipment**: Night Sword can be refilled using nightmare fuel
- **Refill Rate**: Each nightmare fuel restores 20% durability by default
- **Durability Retention**: Option to keep the Night Equipment when durability is exhausted instead of destroying it
- **Function Management**: When durability is low, Night Equipment loses its respective effects (damage and sanity drain effects)

## 配置选项 / Configuration Options

1. **Language/语言**: 选择角色说话的语言 / Choose character speech language
2. **Refill Rate/充能值**: 设置噩梦燃料的充能效果 / Set nightmare fuel refill effectiveness
3. **Equipment Retention/装备保留**: 选择是否在耐久度耗尽时保留暗夜剑 / Choose whether to keep Night Sword when durability is exhausted
4. **Maximum Durability/最大耐久度**: 设置暗夜剑的最大耐久度 / Set maximum durability of Night Sword

## 使用方法 / How to Use

1. 手持噩梦燃料右键暗夜剑进行修复 / Hold the Nightmare Fuel with the right-click on the Dark Night Sword.
2. 每份噩梦燃料会根据配置恢复相应的耐久度 / Each nightmare fuel restores durability according to configuration
3. 当耐久度满时，噩梦燃料会被退还 / Nightmare fuel is returned when durability is full

## 技术实现 / Technical Implementation

这个mod参考了原版法杖和护身符的可充能mod设计，主要技术要点包括：

1. **交易系统**: 通过添加trader组件实现噩梦燃料与暗夜剑的交易
2. **耐久度管理**: 使用finiteuses组件管理耐久度的变化
3. **功能控制**: 通过监听耐久度变化事件来控制武器功能的启用/禁用
4. **PostInit钩子**: 使用AddPrefabPostInit在游戏加载后修改暗夜剑的属性

## 兼容性 / Compatibility

- 适用于饥荒联机版 (Don't Starve Together)
- 需要所有客户端安装此mod
- 兼容大部分其他mod

## 版本历史 / Version History

- v1.0.0: 初始版本，实现基本的暗夜剑充能功能
