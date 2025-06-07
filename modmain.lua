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
	--No Consumption/装备无消耗

if maximum_use == 999 then	AddComponentPostInit("finiteuses", function(Finiteuses, inst)
		Finiteuses.oldUseFn_consumption_on = Finiteuses.Use
		function Finiteuses:Use(num)
			if self.inst:HasTag("no_nightsword_consumption") then
				return
			else
				return Finiteuses:oldUseFn_consumption_on(num)
			end
		end
	end)
end	--Zero Durability Related/零耐久相关

if wont_break then	AddComponentPostInit("finiteuses", function(FiniteUses, inst)
		FiniteUses.oldSetUsesFn_nightsword_fix = FiniteUses.SetUses
		function FiniteUses:SetUses(val)
			if self.inst:HasTag("nightsword_durability_fix") then
				local was_positive = self.current > 0
				self.current = val
				if self.current <= 0 then
					self.current = 0
					if was_positive then
						self.inst:AddTag("usesdepleted")
						if self.onfinished ~= nil then
							self.onfinished(self.inst)
						end
					end
				elseif not was_positive then
					self.inst:RemoveTag("usesdepleted")
				end
				self.inst:PushEvent("percentusedchange", {percent = self:GetPercent()})
			else
				return FiniteUses:oldSetUsesFn_nightsword_fix(val)
			end
		end
	end)
	
	AddComponentPostInit("hauntable", function(Hauntable, inst)
		Hauntable.oldDoHauntFn_no_nightsword_durability = Hauntable.DoHaunt
		function Hauntable:DoHaunt(doer)
			if self.inst:HasTag("nightsword_durability_exhausted") then
				self.haunted = true
				self.cooldowntimer = self.cooldown or TUNING.HAUNT_COOLDOWN_SMALL
				self:StartFX(true)
				self:StartShaderFx()
				self.inst:StartUpdatingComponent(self)
				return
			else
				return Hauntable:oldDoHauntFn_no_nightsword_durability(doer)
			end
		end
	end)
end

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
