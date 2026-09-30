local FUEL_SOUND = "dontstarve/common/nightmareAddFuel"
local FUEL_EVENT = "nightsword_refill.playfuelsound"

-- Match orangeamulet: inventory sounds are heard by players viewing the container.
local function PlayClientFuelSound(inst)
    local parent = inst.entity:GetParent()
    local container = parent ~= nil and (parent.replica.inventory or parent.replica.container) or nil
    if container ~= nil and container:IsOpenedBy(ThePlayer) then
        TheFocalPoint.SoundEmitter:PlaySound(FUEL_SOUND)
    end
end

local function PlayFuelSound(inst)
    local owner = inst.components.inventoryitem.owner
    if owner == nil then
        inst.SoundEmitter:PlaySound(FUEL_SOUND)
    elseif inst.components.equippable:IsEquipped() and owner.SoundEmitter ~= nil then
        owner.SoundEmitter:PlaySound(FUEL_SOUND)
    else
        inst._refill_sound:push()
        if not TheNet:IsDedicated() then
            PlayClientFuelSound(inst)
        end
    end
end

local function Say(doer, english, en, zh)
    if doer ~= nil and doer.components.talker ~= nil then
        doer.components.talker:Say(english and en or zh)
    end
end

local function ConfigureRetention(inst, options)
    local saved_attributes

    local function UpdateDurability()
        local weapon = inst.components.weapon
        local equippable = inst.components.equippable
        if inst.components.finiteuses:GetUses() <= 0 then
            if saved_attributes == nil then
                saved_attributes = {
                    damage = weapon ~= nil and weapon.damage or nil,
                    dapperness = equippable ~= nil and equippable.dapperness or nil,
                }
                if weapon ~= nil then
                    weapon:SetDamage(0)
                end
                if equippable ~= nil then
                    equippable.dapperness = 0
                end
            end
        elseif saved_attributes ~= nil then
            if weapon ~= nil then
                weapon:SetDamage(saved_attributes.damage)
            end
            if equippable ~= nil then
                equippable.dapperness = saved_attributes.dapperness
            end
            saved_attributes = nil
        end
    end

    inst.components.finiteuses:SetOnFinished(function()
        UpdateDurability()
        local owner = inst.components.inventoryitem.owner
        if owner ~= nil and inst.components.equippable:IsEquipped() then
            Say(owner, options.english, "Night Sword durability exhausted.", "暗夜剑耐久度耗尽。")
            if not owner:HasTag("busy") then
                owner:PushEvent("toolbroke", { tool = inst })
            end
        end
    end)

    inst:ListenForEvent("percentusedchange", UpdateDurability)
    -- Component OnLoad runs after prefab initialization, including old zero-use saves.
    inst:DoTaskInTime(0, UpdateDurability)

    local hauntable = inst.components.hauntable
    if hauntable ~= nil and hauntable.onhaunt ~= nil then
        local onhaunt = hauntable.onhaunt
        hauntable:SetOnHauntFn(function(item, haunter)
            if item.components.finiteuses:GetUses() <= 0 then
                return false
            end
            return onhaunt(item, haunter)
        end)
    end
end

local function ConfigureRepair(inst, options)
    local finiteuses = inst.components.finiteuses
    if inst.components.repairable == nil then
        inst:AddComponent("repairable")
    end
    local repairable = inst.components.repairable
    repairable.repairmaterial = MATERIALS.NIGHTMARE
    repairable.noannounce = true
    repairable.testvalidrepairfn = function(_, item)
        return item ~= nil and item.prefab == "nightmarefuel"
    end
    repairable:SetFiniteUsesRepairable(finiteuses:GetUses() < finiteuses.total)

    -- Native Repair handles validation, clamping, stack consumption and callbacks.
    -- Adapt only this sword's repair amount; nightmarefuel and other items stay vanilla.
    local repair = finiteuses.Repair
    finiteuses.Repair = function(self)
        return repair(self, self.total * options.refill_rate)
    end

    repairable.onrepaired = function(item, doer)
        PlayFuelSound(item)
        if finiteuses:GetPercent() >= 1 then
            Say(doer, options.english, "Night Sword fully repaired.", "暗夜剑完全修复。")
        else
            local percent = string.format("%g", options.refill_rate * 100)
            Say(doer, options.english,
                "Night Sword durability restored: "..percent.."%.",
                "暗夜剑耐久度恢复："..percent.."%。")
        end
    end
end

return function(inst, options)
    if options.refill_rate > 0 then
        -- Both peers need the short-action tag and matching sound net variable.
        inst:AddTag("repairshortaction")
        if inst.SoundEmitter == nil then
            inst.entity:AddSoundEmitter()
        end
        inst._refill_sound = net_event(inst.GUID, FUEL_EVENT)
        if not TheWorld.ismastersim then
            inst:DoTaskInTime(0, inst.ListenForEvent, FUEL_EVENT, PlayClientFuelSound)
        end
    end

    if not TheWorld.ismastersim then
        return
    end

    local finiteuses = inst.components.finiteuses
    if finiteuses == nil then
        return
    end

    if options.maximum_use == 999 then
        finiteuses:SetIgnoreCombatDurabilityLoss(true)
    elseif options.maximum_use ~= 1 then
        local percent = finiteuses:GetPercent()
        finiteuses:SetMaxUses(finiteuses.total * options.maximum_use)
        finiteuses:SetPercent(percent)
    end

    if options.wont_break then
        ConfigureRetention(inst, options)
    end
    if options.refill_rate > 0 then
        ConfigureRepair(inst, options)
    end
end
