name = "Refillable Night Sword and Night Armor"
description =
[[
- Night Sword and Night Armor can also be repaired with nightmare fuel.
  暗夜剑和暗夜甲可以使用噩梦燃料修复。
- Each nightmare fuel restores 20% of Night Sword or Night Armor durability by default.
  默认每份噩梦燃料恢复暗夜剑或暗夜甲20%的耐久度。
- Configure Night Sword and Night Armor refill rates separately: 10%, 20%, 25%, 33.3%, 50%, or 100%.
  暗夜剑和暗夜甲可分别设置恢复比例：10%、20%、25%、33.3%、50%或100%。
- Night Sword and Night Armor can be retained when durability is exhausted.
  暗夜剑和暗夜甲在耐久度耗尽时可以被保留。
]]
author = "Lingxiao00294"
version = "1.4.1"

forumthread = ""
api_version = 10

dst_compatible = true
client_only_mod = false
all_clients_require_mod = true

--icon_atlas = "modicon.xml"
--icon = "modicon.tex"

configuration_options =
{
    {
        name = "lang",
        label = "Language/语言",
		hover = "Choose the announcement language or disable character speech".."\n选择播报语言或关闭角色台词",
        options =
        {
            {description = "No Announcements/不播报", data = "none", hover = "Disable repair and durability announcements/关闭修复和耐久耗尽播报"},
            {description = "English", 	data = true, 	hover = "The character will declare the refill in English"},
            {description = "中文", 		data = false, 	hover = "角色将使用中文对充能进行宣告"},
        },
        default = "none",
    },
	{
		name = "refill_rate",
        label = "Night Sword Refill Rate/暗夜剑充能值",
		hover = "Night Sword durability restored by each nightmare fuel".."\n每份噩梦燃料为暗夜剑恢复的耐久度百分比",
        options =
        {
            {description = "10%", 					data = 0.10,	hover = "Increase by 10%/增加10%"},
            {description = "20%", 					data = 0.20,	hover = "Increase by 20%/增加20%"},
            {description = "25%", data = 0.25, hover = "Increase by 25%/增加25%"},
            {description = "33.3%", data = 0.333, hover = "Increase by 33.3%/增加33.3%"},
            {description = "50%", 					data = 0.50,	hover = "Increase by 50%/增加50%"},
            {description = "100%", data = 1, hover = "Fully repair/完全修复"},
        },
        default = 0.20,
	},
    {
        name = "armor_refill_rate",
        label = "Night Armor Refill Rate/暗夜甲充能值",
        hover = "Night Armor durability restored by each nightmare fuel".."\n每份噩梦燃料为暗夜甲恢复的耐久度百分比",
        options =
        {
            {description = "10%", data = 0.10, hover = "Increase by 10%/增加10%"},
            {description = "20%", data = 0.20, hover = "Increase by 20%/增加20%"},
            {description = "25%", data = 0.25, hover = "Increase by 25%/增加25%"},
            {description = "33.3%", data = 0.333, hover = "Increase by 33.3%/增加33.3%"},
            {description = "50%", data = 0.50, hover = "Increase by 50%/增加50%"},
            {description = "100%", data = 1, hover = "Fully repair/完全修复"},
        },
        default = 0.20,
    },
    {
        name = "wont_break",
        label = "Equipment Retention/装备保留",
		hover = "Whether to keep Night Sword and Night Armor when durability is exhausted".."\n暗夜剑和暗夜甲耐久耗尽时是否保留",
        options =
        {
			{description = "Yes/是", 	data = true, 	hover = "Keep Night Sword and Night Armor/保留暗夜剑和暗夜甲"},
            {description = "No/否", 	data = false, 	hover = "Remove Night Sword and Night Armor/移除暗夜剑和暗夜甲"},
        },
        default = true,
    },
    {
        name = "maximum_use",
        label = "Maximum Durability/最大耐久度",
		hover = "The maximum durability of Night Sword and Night Armor".."\n暗夜剑和暗夜甲的耐久度上限",
        options =
        {
			{description = "Default/默认", 		data = 1,		hover = "Default values (Night Sword: 100, Night Armor: 525)/默认值（暗夜剑：100，暗夜甲：525）"},
            {description = "200%", 				data = 2,		hover = "200% of default value/默认值的200%"},
            {description = "500%", 				data = 5,		hover = "500% of default value/默认值的500%"},
			{description = "Infinity/无限", 	data = 999,		hover = "Night Sword and Night Armor do not lose combat durability/暗夜剑和暗夜甲不会损失战斗耐久"},
        },
        default = 1,
	},
}
