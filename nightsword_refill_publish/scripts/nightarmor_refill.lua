local FUEL_SOUND = "dontstarve/common/nightmareAddFuel"
local FUEL_EVENT = "nightarmor_refill.playfuelsound"

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

local function ConfigureRetention(inst, armor)
    armor:SetKeepOnFinished(true)
    local equippable = inst.components.equippable
    local shadowlevel = inst.components.shadowlevel
    local saved_attributes

    local function UpdateDurability()
        if armor.condition <= 0 then
            if saved_attributes == nil then
                saved_attributes = {
                    absorption = armor.absorb_percent,
                    dapperness = equippable ~= nil and equippable.dapperness or nil,
                    shadowlevel = shadowlevel ~= nil and shadowlevel.level or nil,
                }
                armor:SetAbsorption(0)
                if equippable ~= nil then
                    equippable.dapperness = 0
                end
                if shadowlevel ~= nil then
                    shadowlevel:SetDefaultLevel(0)
                end
            end
        elseif saved_attributes ~= nil then
            armor:SetAbsorption(saved_attributes.absorption)
            if equippable ~= nil then
                equippable.dapperness = saved_attributes.dapperness
            end
            if shadowlevel ~= nil then
                shadowlevel:SetDefaultLevel(saved_attributes.shadowlevel)
            end
            saved_attributes = nil
        end
    end

    inst:ListenForEvent("percentusedchange", UpdateDurability)
    -- Armor OnLoad runs after prefab initialization, including old zero-condition saves.
    inst:DoTaskInTime(0, UpdateDurability)
end

local function ConfigureRepair(inst, armor, options)
    if inst.components.repairable == nil then
        inst:AddComponent("repairable")
    end
    local repairable = inst.components.repairable
    repairable.repairmaterial = MATERIALS.NIGHTMARE
    repairable.noannounce = true
    repairable.justrunonrepaired = true
    repairable.testvalidrepairfn = function(_, item)
        return item ~= nil and item.prefab == "nightmarefuel" and armor:IsDamaged()
    end

    local function UpdateRepairAction()
        -- Nightmare fuel advertises a finiteuses repair. This tag makes the
        -- native right-click action available only while this armor is damaged.
        repairable:SetFiniteUsesRepairable(armor:IsDamaged())
    end
    inst:ListenForEvent("percentusedchange", UpdateRepairAction)
    UpdateRepairAction()

    -- Native Repair checks material and consumes one fuel before this callback.
    repairable.onrepaired = function(item, doer)
        armor:Repair(armor.maxcondition * options.refill_rate)
        PlayFuelSound(item)
        if not armor:IsDamaged() then
            Say(doer, options.english, "Night Armor fully repaired.", "暗夜甲完全修复。")
        else
            local percent = string.format("%g", options.refill_rate * 100)
            Say(doer, options.english,
                "Night Armor durability restored: "..percent.."%.",
                "暗夜甲耐久度恢复："..percent.."%。")
        end
    end
end

return function(inst, options)
    if options.refill_rate > 0 then
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

    local armor = inst.components.armor
    if armor == nil then
        return
    end

    if options.maximum_use == 999 then
        armor.conditionlossmultipliers:SetModifier("nightarmor_refill", 0)
    elseif options.maximum_use ~= 1 then
        local percent = armor:GetPercent()
        armor.maxcondition = armor.maxcondition * options.maximum_use
        armor:SetPercent(percent)
    end

    if options.wont_break then
        ConfigureRetention(inst, armor)
    end
    if options.refill_rate > 0 then
        ConfigureRepair(inst, armor, options)
    end
end
