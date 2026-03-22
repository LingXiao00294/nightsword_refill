local TUNING = GLOBAL.TUNING

local refill_rate = GetModConfigData("refill_rate") or 0.20
local maximum_use = GetModConfigData("maximum_use") or 1
local wont_break = GetModConfigData("wont_break")
	--Maximum Capacity/最大容量

if maximum_use < 999 then
	if TUNING.NIGHTSWORD_USES then
		TUNING.NIGHTSWORD_USES = TUNING.NIGHTSWORD_USES * maximum_use
	else
		print("Refillable Night Sword: TUNING.NIGHTSWORD_USES not found!")
	end
end

	--Import Scripts/导入脚本

modimport("scripts/nightequipment_import")

	--Nightmare Fuel Tradable/噩梦燃料可交易

if refill_rate > 0 then
	AddPrefabPostInit("nightmarefuel", function(inst)
		if GLOBAL.TheWorld.ismastersim then
			if inst.components.tradable == nil then
				inst:AddComponent("tradable")
			end
		end
	end)
end
