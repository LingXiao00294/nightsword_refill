local TUNING = GLOBAL.TUNING
local SpawnPrefab = GLOBAL.SpawnPrefab
local Vector3 = GLOBAL.Vector3
local DEGREES = GLOBAL.DEGREES

local is_english = GetModConfigData("lang")
local refill_rate = GetModConfigData("refill_rate") or 0.20
local maximum_use = GetModConfigData("maximum_use") or 1
local wont_break = GetModConfigData("wont_break")
	--Only Remove the Function for Night Sword/只有暗夜剑功能被移除
	
local function nightsword_break(inst)
	local owner = inst.components.inventoryitem.owner
	if owner ~= nil and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
		if owner.components.talker ~= nil then
			if is_english then
				owner.components.talker:Say("Night Sword durability exhausted.")
			else
				owner.components.talker:Say("暗夜剑耐久度耗尽。")
			end
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
	return item ~= nil and item.prefab == "nightmarefuel"
end

local function on_accept_nightsword(inst, giver, item)
	if item ~= nil and item.prefab == "nightmarefuel" then
		if inst.components.finiteuses ~= nil then
			local current_percent = inst.components.finiteuses:GetPercent()
			if current_percent >= 1 then
				if giver.components.talker ~= nil then
					if is_english then
						giver.components.talker:Say("Night Sword durability is full already.")
					else
						giver.components.talker:Say("暗夜剑耐久度已满。")
					end
				end
				-- Return the nightmare fuel if durability is already full
				inst:DoTaskInTime(0.1, function()
					local giveBack = SpawnPrefab(item.prefab)
					local pitPos = Vector3(inst.Transform:GetWorldPosition())
					local pt = pitPos + Vector3(0, 1, 0)
					giveBack.Transform:SetPosition(pt:Get())
					local angle = (math.random() * 360) * DEGREES
					local sp = 3 + math.random()
					giveBack.Physics:SetVel(sp * math.cos(angle), math.random() * 2 + 4, sp * math.sin(angle))
					giver.SoundEmitter:PlaySound("dontstarve/pig/PigKingThrowGold")
				end)
			else
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
					if current_percent >= 1 then
						if is_english then
							giver.components.talker:Say("Night Sword fully repaired.")
						else
							giver.components.talker:Say("暗夜剑完全修复。")
						end
					else
						if is_english then
							giver.components.talker:Say("Night Sword durability restored: "..(refill_rate * 100).."%.")
						else
							giver.components.talker:Say("暗夜剑耐久度恢复："..(refill_rate * 100).."%。")
						end
					end
				end				-- Restore functionality if durability was 0
				if inst:HasTag("nightsword_durability_exhausted") then
					-- Restore weapon damage (Night Sword does 68 damage by default)
					if inst.components.weapon ~= nil then
						inst.components.weapon:SetDamage(68)
					end
					-- Restore sanity drain
					if inst.components.equippable ~= nil then
						inst.components.equippable.dapperness = -TUNING.DAPPERNESS_MED
					end
					inst:RemoveTag("nightsword_durability_exhausted")
				end
			end
		end
	end
end

	--Add or Lose Function for Night Sword/添加或移除暗夜剑功能

local function lose_function_nightsword(inst)
	if inst.components.finiteuses ~= nil and inst.components.finiteuses:GetPercent() > 0 then
		if inst.components.finiteuses:GetUses() < 0.999 then
			-- Reduce damage when durability is low
			if inst.components.weapon ~= nil then
				inst.components.weapon:SetDamage(0)
			end
			-- Remove sanity effect when durability is low
			if inst.components.equippable ~= nil then
				inst.components.equippable.dapperness = 0
			end
			if inst.components.finiteuses:GetUses() < 0.001 then
				inst.components.finiteuses:SetPercent(0)
			end		else
			-- Restore full functionality when durability is sufficient
			if inst.components.weapon ~= nil then
				inst.components.weapon:SetDamage(68)  -- Night Sword default damage
			end
			if inst.components.equippable ~= nil then
				inst.components.equippable.dapperness = -TUNING.DAPPERNESS_MED
			end
		end
	end
end
	--Modify Prefab Files/修改预制件
	
AddPrefabPostInit("nightsword", function(inst)
	if GLOBAL.TheWorld.ismastersim then
		-- Add infinite durability tag if maximum_use is set to infinity
		if maximum_use == 999 then
			inst:AddTag("no_nightsword_consumption")
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
			end
			
			-- Add functionality loss when durability is low
			inst:ListenForEvent("percentusedchange", lose_function_nightsword)
			inst:DoTaskInTime(0, lose_function_nightsword)
		end
	end
end)
