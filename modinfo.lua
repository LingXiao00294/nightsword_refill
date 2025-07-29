name = "Refillable Night Sword"
description = 
[[
- Night Sword can be refilled with nightmare fuel.
  暗夜剑可以使用噩梦燃料充能。
- Each nightmare fuel restores 20% of the equipment's durability.
  每份噩梦燃料恢复装备20%的耐久度。
- Night Sword can be retained when durability is exhausted.
  暗夜剑在耐久度耗尽时可以被保留。
]]
author = "ModCreator"
version = "1.1.0"

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
		hover = "The language you prefer for character speech".."\n你希望角色使用的语言",
        options =
        {
            {description = "English", 	data = true, 	hover = "The character will declare the refill in English"},
            {description = "中文", 		data = false, 	hover = "角色将使用中文对充能进行宣告"},
        },
        default = false,
    },
	{
		name = "refill_rate",
        label = "Refill Rate/充能值",
		hover = "The percentage of durability that can be increased by each nightmare fuel".."\n每一份噩梦燃料可以增加的耐久度百分比",
        options =
        {
			{description = "No Refill/不充能", 		data = 0,		hover = "Night Sword can not be refilled/暗夜剑不可被充能"},
            {description = "10%", 					data = 0.10,	hover = "Increase by 10%/增加10%"},
            {description = "20%", 					data = 0.20,	hover = "Increase by 20%/增加20%"},
            {description = "30%", 					data = 0.30,	hover = "Increase by 30%/增加30%"},
            {description = "50%", 					data = 0.50,	hover = "Increase by 50%/增加50%"},
        },
        default = 0.20,
	},
    {
        name = "wont_break",
        label = "Equipment Retention/装备保留",
		hover = "Whether to keep the Night Sword when its durability is exhausted".."\n是否在暗夜剑耐久度耗尽时保留装备",
        options =
        {
			{description = "Yes/是", 	data = true, 	hover = "Keep the Night Sword/保留暗夜剑"},
            {description = "No/否", 	data = false, 	hover = "Remove the Night Sword/移除暗夜剑"},
        },
        default = true,
    },
    {
        name = "maximum_use",
        label = "Maximum Durability/最大耐久度",
		hover = "The maximum durability of the Night Sword".."\n暗夜剑的耐久度上限",
        options =
        {
			{description = "Default/默认", 		data = 1,		hover = "Default value (Night Sword: 100)/默认值（暗夜剑：100）"},
            {description = "200%", 				data = 2,		hover = "200% of default value/默认值的200%"},
            {description = "500%", 				data = 5,		hover = "500% of default value/默认值的500%"},
			{description = "Infinity/无限", 	data = 999,		hover = "Night Sword won't lose durability/暗夜剑不会损失耐久度"},
        },
        default = 1,
	},
}
