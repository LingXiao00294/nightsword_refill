local GLOBAL = GLOBAL
local TUNING = GLOBAL.TUNING

local is_english = GetModConfigData("lang")
local refill_rate = GetModConfigData("refill_rate") or 0.20
local maximum_use = GetModConfigData("maximum_use") or 1
local wont_break = GetModConfigData("wont_break")

-- Pre-calculate localized strings and constants
local STRINGS_MSG = {
	EXHAUSTED = is_english and "Night Sword durability exhausted." or "暗夜剑耐久度耗尽。",
	FULLY_REPAIRED = is_english and "Night Sword fully repaired." or "暗夜剑完全修复。",
	REFILL_PREFIX = is_english and "Night Sword durability restored: " or "暗夜剑耐久度恢复：",
	REFILL_SUFFIX = (refill_rate * 100).."%.",
}
local REFILL_MSG = STRINGS_MSG.REFILL_PREFIX .. STRINGS_MSG.REFILL_SUFFIX

local NIGHTSWORD_DAMAGE = 68
local NIGHTSWORD_DAPPERNESS = -TUNING.DAPPERNESS_MED
local HAUNT_COOLDOWN_SMALL = TUNING.HAUNT_COOLDOWN_SMALL

	--Only Remove the Function for Night Sword/只有暗夜剑功能被移除
	
local function nightsword_break(inst)
	local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
	if owner ~= nil and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
		if owner.components.talker ~= nil then
			owner.components.talker:Say(STRINGS_MSG.EXHAUSTED)
		end
		if not owner:HasTag("busy") then
			owner:PushEvent("toolbroke", {tool = inst})
		end
	end
	-- Remove weapon functionality when durability is exhausted
	if inst.components.weapon ~= nil then
		inst.components.weapon:SetDamage(0)
	end	-- Remove sanity drain functionality
	if inst.components.equippable ~= nil then
		inst.components.equippable.dapperness = 0
	end
	inst:AddTag("nightsword_durability_exhausted")
end

	--Refill for Night Sword/暗夜剑充能
	
local function accept_test_nightsword(inst, item)
	if item ~= nil and item.prefab == "nightmarefuel" then
		-- Only accept nightmare fuel if durability is not full
		if inst.components.finiteuses ~= nil then
			local current_percent = inst.components.finiteuses:GetPercent()
			return current_percent < 0.999
		end
	end
	return false
end

local function on_accept_nightsword(inst, giver, item)
	if item ~= nil and item.prefab == "nightmarefuel" then
		if inst.components.finiteuses ~= nil then
			local current_percent = inst.components.finiteuses:GetPercent()
			
			giver.SoundEmitter:PlaySound("dontstarve/common/nightmareAddFuel")
			
			-- Calculate new durability
			current_percent = current_percent + refill_rate
			if current_percent >= 0.999 then
				current_percent = 1
			end
			
			-- Set new durability
			inst.components.finiteuses:SetPercent(current_percent)
			
			-- Feedback to player
			if giver.components.talker ~= nil then
				giver.components.talker:Say(current_percent >= 1 and STRINGS_MSG.FULLY_REPAIRED or REFILL_MSG)
			end
			-- Functionality restoration (weapon damage/dapperness) is handled via
			-- the "percentusedchange" listener (update_nightsword_functionality).
		end
	end
end

	--Add or Lose Function for Night Sword/添加或移除暗夜剑功能

local function update_nightsword_functionality(inst)
	if inst.components.finiteuses == nil then return end

	local current_uses = inst.components.finiteuses:GetUses()
	local is_exhausted = current_uses < 0.999
	local has_exhausted_tag = inst:HasTag("nightsword_durability_exhausted")

	if is_exhausted and not has_exhausted_tag then
		-- Entering exhausted state
		if inst.components.weapon ~= nil then
			inst.components.weapon:SetDamage(0)
		end
		if inst.components.equippable ~= nil then
			inst.components.equippable.dapperness = 0
		end
		inst:AddTag("nightsword_durability_exhausted")

		if current_uses < 0.001 then
			inst.components.finiteuses:SetPercent(0)
		end
	elseif not is_exhausted and has_exhausted_tag then
		-- Exiting exhausted state
		if inst.components.weapon ~= nil then
			inst.components.weapon:SetDamage(NIGHTSWORD_DAMAGE)
		end
		if inst.components.equippable ~= nil then
			inst.components.equippable.dapperness = NIGHTSWORD_DAPPERNESS
		end
		inst:RemoveTag("nightsword_durability_exhausted")
	end
end
	--Modify Prefab Files/修改预制件
	
AddPrefabPostInit("nightsword", function(inst)
	if not GLOBAL.TheWorld.ismastersim then return end

	-- Add infinite durability tag if maximum_use is set to infinity
	if maximum_use == 999 then
		inst:AddTag("no_nightsword_consumption")
		
		if inst.components.finiteuses ~= nil then
			local finiteuses = inst.components.finiteuses
			finiteuses.oldUseFn_consumption_on = finiteuses.Use
			function finiteuses:Use(num)
				if self.inst:HasTag("no_nightsword_consumption") then
					return
				else
					return self:oldUseFn_consumption_on(num)
				end
			end
		end
	end

	-- Add trader component for nightmare fuel refill
	if refill_rate > 0 and inst.components.trader == nil then
		inst:AddComponent("trader")
		inst.components.trader:SetAbleToAcceptTest(accept_test_nightsword)
		inst.components.trader.onaccept = on_accept_nightsword
	end

	if inst.components.finiteuses ~= nil then
		-- Set up durability retention when wont_break is enabled
		if wont_break then
			inst:AddTag("nightsword_durability_fix")
			inst.components.finiteuses:SetOnFinished(nightsword_break)

			local finiteuses = inst.components.finiteuses
			finiteuses.oldSetUsesFn_nightsword_fix = finiteuses.SetUses
			function finiteuses:SetUses(val)
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
					return self:oldSetUsesFn_nightsword_fix(val)
				end
			end
		end
		
		-- Add functionality loss when durability is low
		inst:ListenForEvent("percentusedchange", update_nightsword_functionality)
		inst:DoTaskInTime(0, update_nightsword_functionality)
	end

	-- Per-instance hauntable override to avoid global ComponentPostInit overhead
	if wont_break and inst.components.hauntable ~= nil then
		local hauntable = inst.components.hauntable
		hauntable.oldDoHauntFn_no_nightsword_durability = hauntable.DoHaunt
		function hauntable:DoHaunt(doer)
			if self.inst:HasTag("nightsword_durability_exhausted") then
				self.haunted = true
				self.cooldowntimer = self.cooldown or HAUNT_COOLDOWN_SMALL
				self:StartFX(true)
				self:StartShaderFx()
				self.inst:StartUpdatingComponent(self)
				return
			else
				return self:oldDoHauntFn_no_nightsword_durability(doer)
			end
		end
	end
end)
