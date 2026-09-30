# Refillable Night Sword and Night Armor

饥荒联机版暗夜剑和暗夜甲充能模组。两种装备均可使用噩梦燃料恢复耐久，并提供耐久倍率、无限耐久和耗尽保留选项。

## 使用方法

1. 拿起噩梦燃料，右键需要修复的暗夜剑或暗夜甲，操作与原版橙色护符（懒人护符 / Lazy Forager）相同。
2. 使用原版“修复”动作及短动作动画；背包、装备栏和地面物品沿用原版的目标判定。
3. 每次消耗一份噩梦燃料，默认恢复最大耐久的 20%，最多恢复到 100%。满耐久时不提供修复动作，也不会消耗燃料。
4. 默认保留耐久耗尽的装备。暗夜剑此时武器伤害和装备理智消耗为零；暗夜甲此时不再吸收伤害，也不再产生装备理智效果和暗影等级。补充耐久后恢复耗尽前的属性。

本模组只修改暗夜剑和暗夜甲，不扩展到其他暗夜装备。需要服务端和所有客户端安装。

## 配置

| 配置 | 可选值 | 默认值 |
| --- | --- | --- |
| Language / 语言 | 中文、English；控制修复和耗尽提示 | 中文 |
| Refill Rate / 充能值 | 禁用、10%、20%、30%、50% | 20% |
| Equipment Retention / 装备保留 | 耗尽时保留或销毁 | 保留 |
| Maximum Durability / 最大耐久度 | 原版、200%、500%、无限 | 原版 |

充能比例按各自配置后的最大耐久计算，例如暗夜剑 200 次耐久、20% 充能时，每份恢复 40 次；暗夜甲原版 525 点耐久时，每份恢复 105 点。无限耐久下，暗夜剑使用原版“不消耗战斗耐久”设置，暗夜甲使用自身的零损耗倍率；旧存档中受损的装备仍可修复。禁用充能后不再提供修复动作；同时开启装备保留时，耗尽的装备会留下，但无法用本模组修复。

## 实现与存档

- 采用原版橙色护符的 `repairable`、`MATERIALS.NIGHTMARE`、`repairshortaction` 和 `ACTIONS.REPAIR` 流程。噩梦燃料本身已有 `repairer` 组件，无需添加交易组件或修改燃料。
- 暗夜剑保留原版 `finiteuses` 作为唯一耐久数据源，只在剑实例上适配每次修复的耐久量。
- 暗夜甲保留原版 `armor.condition` 作为耐久数据源。原版 `repairable` 不直接处理护甲耐久，因此用 `justrunonrepaired` 在原版材料校验和单份燃料消耗后调用护甲修复；满耐久时移除修复动作并拒绝消耗。
- 保留原版 `usesdepleted` 标签和 `SetUses` 行为；不修改全局组件方法或 `TUNING`，不注册额外动作，不使用定时燃烧机制。
- 耗尽后保存并恢复暗夜剑的实际武器伤害与理智属性，以及暗夜甲的实际吸收率、理智属性和暗影等级。仍有正数耐久时保留装备效果。
- 音效按原版护符区分地面、装备及容器，并通过网络事件通知查看容器的客户端。
- 继续读取原有 `finiteuses` 和 `armor` 存档，包括零耐久装备，无需转换存档。修改耐久倍率后，已有受损装备沿用原版保存的剩余耐久值。

同时修改这两种装备的组件、伤害或修复行为的其他模组可能受加载顺序影响，不能保证全部兼容。

## 上传创意工坊

上传工具的 **Update Data** 选择仓库下的 `nightsword_refill_publish/`，其中仅包含 `modinfo.lua`、`modmain.lua`、`mod.manifest` 和 `scripts/` 下的 `nightsword_refill.lua`、`nightarmor_refill.lua`。源码更新后需重新同步这些文件再上传。

当前模组未启用自定义图标，不需要上传 `modicon.xml`。创意工坊封面在仓库根目录：`preview.jpg` 为上传版本，`preview.png` 为生成原图。勾选 **Update Preview Image** 并选择 `preview.jpg` 即可更新封面；封面由工具单独上传，不放入 `nightsword_refill_publish/`。不更换封面时取消该选项。生成提示词见 `preview.prompt.md`。

## 验证

自动测试需要 Lua 5.1 和本机饥荒联机版的 `data/databundles/scripts.zip`，从仓库根目录运行：

```powershell
.\tests\run.ps1 -GameScripts 'D:\Programs\Steam\steamapps\common\Don''t Starve Together\data\databundles\scripts.zip' -Lua 'lua'
```

也可将 `-Lua` 指定为 Lua 5.1 可执行文件的完整路径，并按实际安装位置修改 `-GameScripts`。测试从本机游戏读取真实的 `armor`、`finiteuses`、`repairable`、`repairer`、修复动作和战斗损耗代码，临时提取后运行，不修改游戏文件，也不分发游戏源码。

覆盖两种装备的各档充能比例与耐久倍率、满耐久拒绝、错误材料、堆叠消耗、耗尽与恢复、旧存档加载、无限耐久、禁用选项、其他装备隔离、客户端初始化和音效分支。引擎实体与网络使用替身，实际联机交互仍需进游戏验收：

- 房主和远程客户端分别修复背包、装备栏、地面及容器中的暗夜剑和暗夜甲，检查动作、动画、耐久显示与音效。
- 连续修复至满耐久，确认每次只少一份燃料，满耐久无法继续消耗。
- 将两种装备用至耗尽，保存重进后修复，确认剑的伤害及甲的吸收率与理智属性恢复。
- 分别检查关闭保留、关闭充能及无限耐久配置，并确认原版橙色护符不受影响。

## English

Night Sword and Night Armor can also be repaired with Nightmare Fuel using the same native repair interaction as the Lazy Forager. Each fuel restores a configurable percentage of either item's maximum durability (20% by default). A fully repaired Night Sword or Night Armor does not consume fuel. Optional retention keeps exhausted equipment inert until it is repaired. Durability multipliers and infinite combat durability remain configurable. All clients require the mod.

## 版本历史

- **1.3.0**：新增暗夜甲充能，沿用原版护甲耐久、修复动作及共享配置；耗尽保留时暂时禁用护甲效果。
- **1.2.0**：改用原版橙色护符修复流程；移除全局组件补丁；修正属性恢复、低耐久及零耐久读档处理；加入原版组件回归测试。
- **1.1.0**：原有噩梦燃料交易充能、耐久配置与耗尽保留实现。
