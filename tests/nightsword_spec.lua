-- Lua 5.1 integration tests using real DST components and action handlers.
local game = assert(arg[1], "Pass an extracted game scripts directory")
package.path = "scripts/?.lua;"..game.."/?.lua;"..package.path
require("class")

MATERIALS = { NIGHTMARE = "nightmare", WOOD = "wood" }
ACTIONS = { REPAIR = {}, ATTACK = {} }
EQUIPSLOTS = { BODY = "body" }
TheWorld = { ismastersim = true }
local dedicated = true
TheNet = { IsDedicated = function() return dedicated end }
ThePlayer = {}
EntityScript = { is_instance = function() return false end }
ProfileStatsSet = function() end
local client_sounds = 0
TheFocalPoint = { SoundEmitter = { PlaySound = function() client_sounds = client_sounds + 1 end } }
net_event = function()
    return { count = 0, push = function(self) self.count = self.count + 1 end }
end

local function ExtractFunction(file, pattern, prefix)
    local handle = assert(io.open(game.."/"..file, "r"))
    local source = handle:read("*a"):gsub("\r", "")
    handle:close()
    local body = assert(source:match(pattern), "Game function not found: "..file)
    return assert(loadstring("return "..(prefix or "")..body.."\nend", file))()
end

local NativeRepair = ExtractFunction("actions.lua", "ACTIONS%.REPAIR%.fn = (function%(act%).-)\nend")
local CollectRepair = ExtractFunction("componentactions.lua",
    "repairer = (function%(inst, doer, target, actions, right%).-)\n        end,")
local NativeAttack = ExtractFunction("components/weapon.lua",
    "function Weapon:OnAttack%(attacker, target, projectile%)(.-)\nend",
    "function(self, attacker, target, projectile)")
local FiniteUses = require("components/finiteuses")
local Configure = require("nightsword_refill")
local ConfigureArmor = require("nightarmor_refill")
local function Equal(actual, expected)
    assert(actual == expected, tostring(actual).." ~= "..tostring(expected))
end
local function Near(actual, expected)
    assert(math.abs(actual - expected) < 0.000001, tostring(actual).." ~= "..tostring(expected))
end

local function Entity()
    local inst = { components = {}, replica = {}, tags = {}, events = {}, tasks = {}, sounds = 0, GUID = 1 }
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:Remove() self.removed = true end
    function inst:IsValid() return not self.removed end
    function inst:ListenForEvent(event, fn)
        self.events[event] = self.events[event] or {}
        table.insert(self.events[event], fn)
    end
    function inst:PushEvent(event, data)
        for _, fn in ipairs(self.events[event] or {}) do fn(self, data) end
    end
    function inst:DoTaskInTime(_, fn, ...)
        table.insert(self.tasks, { fn = fn, args = { ... } })
    end
    function inst:RunTasks()
        local tasks = self.tasks
        self.tasks = {}
        for _, task in ipairs(tasks) do task.fn(self, unpack(task.args)) end
    end
    function inst:AddComponent(name) self.components[name] = require("components/"..name)(self) end
    inst.entity = {
        GetParent = function() return inst.parent end,
        AddSoundEmitter = function()
            inst.SoundEmitter = { PlaySound = function() inst.sounds = inst.sounds + 1 end }
        end,
    }
    return inst
end

local function Sword(overrides)
    local inst = Entity()
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.weapon = { inst = inst, damage = 91, SetDamage = function(self, value) self.damage = value end,
        attackwearmultipliers = { Get = function() return 1 end } }
    inst.components.equippable = { dapperness = -7, IsEquipped = function(self) return self.equipped end }
    inst.components.inventoryitem = {}
    inst.components.hauntable = { onhaunt = function() return "launched" end,
        SetOnHauntFn = function(self, fn) self.onhaunt = fn end }
    local options = { refill_rate = .2, maximum_use = 1, wont_break = true, english = false }
    for key, value in pairs(overrides or {}) do options[key] = value end
    Configure(inst, options)
    return inst
end

local function NightArmor(overrides)
    local inst = Entity()
    inst.prefab = "armor_sanity"
    inst:AddComponent("armor")
    inst.components.armor:InitCondition(525, .95)
    inst.components.equippable = { dapperness = -3, IsEquipped = function(self) return self.equipped end }
    inst.components.shadowlevel = { level = 2, SetDefaultLevel = function(self, value) self.level = value end }
    inst.components.inventoryitem = {}
    local options = { refill_rate = .2, maximum_use = 1, wont_break = true, english = false }
    for key, value in pairs(overrides or {}) do options[key] = value end
    ConfigureArmor(inst, options)
    return inst
end

local function Fuel(count, prefab, material)
    local item = Entity()
    item.prefab = prefab or "nightmarefuel"
    item:AddComponent("repairer")
    item.components.repairer.repairmaterial = material or MATERIALS.NIGHTMARE
    item.components.repairer.finiteusesrepairvalue = 25
    item.count = count or 1
    item.consumed = 0
    item.components.stackable = { Get = function()
        item.count = item.count - 1
        return { Remove = function() item.consumed = item.consumed + 1 end }
    end }
    return item
end

local function Repair(inst, fuel, doer)
    return NativeRepair({ target = inst, invobject = fuel, doer = doer })
end
local function HasRepairAction(inst, fuel)
    local actions = {}
    CollectRepair(fuel, Entity(), inst, actions, true)
    return actions[1] == ACTIONS.REPAIR
end

local passed = 0
local function Test(name, fn)
    fn()
    passed = passed + 1
    print("PASS "..name)
end

Test("mod entry registers only night sword and night armor prefabs", function()
    local hooks = {}
    local env = setmetatable({ GetModConfigData = function() end,
        AddPrefabPostInit = function(name, fn) hooks[name] = fn end }, { __index = _G })
    local main = assert(loadfile("modmain.lua"))
    setfenv(main, env)()
    Equal(type(hooks.nightsword), "function")
    Equal(type(hooks.armor_sanity), "function")
    local count = 0
    for _ in pairs(hooks) do count = count + 1 end
    Equal(count, 2)
    assert(loadfile("modinfo.lua"))
end)

Test("native action availability, single stack consumption and full rejection", function()
    local inst, fuel = Sword(), Fuel(5)
    Equal(HasRepairAction(inst, fuel), false)
    Equal(Repair(inst, fuel), false)
    Equal(fuel.count, 5)
    inst.components.finiteuses:SetPercent(.85)
    Equal(HasRepairAction(inst, fuel), true)
    Equal(Repair(inst, fuel), true)
    Near(inst.components.finiteuses:GetPercent(), 1)
    Equal(fuel.count, 4)
    Equal(fuel.consumed, 1)
    Equal(HasRepairAction(inst, fuel), false)
    Equal(Repair(inst, fuel), false)
    Equal(inst.sounds, 1)
    Equal(inst.components.trader, nil)
end)

Test("all refill rates and finite durability multipliers", function()
    for _, rate in ipairs({ .1, .2, .3, .5 }) do
        for _, multiplier in ipairs({ 1, 2, 5 }) do
            local inst = Sword({ refill_rate = rate, maximum_use = multiplier })
            Equal(inst.components.finiteuses.total, 100 * multiplier)
            inst.components.finiteuses:SetPercent(.1)
            Equal(Repair(inst, Fuel()), true)
            Near(inst.components.finiteuses:GetPercent(), .1 + rate)
        end
    end
end)

Test("wrong prefab/material and standalone fuel", function()
    local inst = Sword()
    inst.components.finiteuses:SetPercent(.5)
    for _, fuel in ipairs({ Fuel(2, "twigs", MATERIALS.WOOD), Fuel(2, "modded_fuel") }) do
        Equal(Repair(inst, fuel), false)
        Equal(fuel.count, 2)
    end
    local fuel = Fuel()
    fuel.components.stackable = nil
    Equal(Repair(inst, fuel), true)
    Equal(fuel.removed, true)
end)

Test("zero durability retains item and restores actual attributes repeatedly", function()
    local inst = Sword()
    for _ = 1, 2 do
        inst.components.finiteuses:Use(1000)
        Equal(inst.removed, nil)
        Equal(inst.components.weapon.damage, 0)
        Equal(inst.components.equippable.dapperness, 0)
        Equal(inst:HasTag("usesdepleted"), true)
        Equal(inst.components.hauntable.onhaunt(inst), false)
        Equal(Repair(inst, Fuel()), true)
        Equal(inst.components.weapon.damage, 91)
        Equal(inst.components.equippable.dapperness, -7)
        Equal(inst:HasTag("usesdepleted"), false)
        Equal(inst.components.hauntable.onhaunt(inst), "launched")
    end
end)

Test("fractional positive durability remains usable", function()
    local inst = Sword()
    inst.components.finiteuses:SetUses(.5)
    Equal(inst.components.weapon.damage, 91)
    NativeAttack(inst.components.weapon)
    Equal(inst.components.weapon.damage, 0)
end)

Test("disabled retention uses native removal", function()
    local inst = Sword({ wont_break = false })
    NativeAttack(inst.components.weapon)
    Equal(inst.components.finiteuses:GetUses(), 99)
    inst.components.finiteuses:Use(99)
    Equal(inst.removed, true)
end)

Test("disabled refill does not add actions or sound networking", function()
    local inst = Sword({ refill_rate = 0 })
    Equal(inst.components.repairable, nil)
    Equal(inst._refill_sound, nil)
    Equal(inst:HasTag("repairshortaction"), false)
    inst.components.finiteuses:Use(100)
    Equal(inst.removed, nil)
end)

Test("infinite durability uses the native combat flag", function()
    local inst = Sword({ maximum_use = 999 })
    for _ = 1, 110 do NativeAttack(inst.components.weapon) end
    Equal(inst.components.finiteuses:GetUses(), 100)
    Equal(inst.components.finiteuses.Use, FiniteUses.Use)
    local normal = Sword()
    NativeAttack(normal.components.weapon)
    Equal(normal.components.finiteuses:GetUses(), 99)
end)

Test("existing finiteuses saves including zero survive load and refill", function()
    for _, uses in ipairs({ 0, 37, 100 }) do
        local inst = Sword()
        inst.components.finiteuses:OnLoad({ uses = uses })
        inst:RunTasks()
        Equal(inst.components.finiteuses:GetUses(), uses)
        Equal(inst.components.weapon.damage, uses == 0 and 0 or 91)
        local data = inst.components.finiteuses:OnSave()
        local reloaded = Sword()
        if data then reloaded.components.finiteuses:OnLoad(data) end
        reloaded:RunTasks()
        Equal(reloaded.components.finiteuses:GetUses(), uses)
        if uses < 100 then
            Equal(Repair(reloaded, Fuel()), true)
            Equal(reloaded.components.weapon.damage, 91)
        end
    end
end)

Test("other finiteuses items and fuel repair values stay vanilla", function()
    local inst = Entity()
    inst:AddComponent("finiteuses")
    inst:AddComponent("repairable")
    inst.components.repairable.repairmaterial = MATERIALS.NIGHTMARE
    inst.components.finiteuses:SetUses(1)
    local fuel = Fuel(3)
    Equal(Repair(inst, fuel), true)
    Equal(inst.components.finiteuses:GetUses(), 26)
    Equal(fuel.components.repairer.finiteusesrepairvalue, 25)
end)

Test("equipped and inventory sound paths plus English speech", function()
    local inst = Sword({ english = true })
    local owner = Entity()
    owner.entity:AddSoundEmitter()
    local speech
    owner.components.talker = { Say = function(_, message) speech = message end }
    owner.replica.inventory = { IsOpenedBy = function(_, player) return player == ThePlayer end }
    inst.components.inventoryitem.owner = owner
    inst.components.equippable.equipped = true
    inst.components.finiteuses:SetUses(0)
    Equal(speech, "Night Sword durability exhausted.")
    Repair(inst, Fuel(), owner)
    Equal(speech, "Night Sword durability restored: 20%.")
    Equal(owner.sounds, 1)
    inst.components.equippable.equipped = false
    Repair(inst, Fuel(), owner)
    Equal(inst._refill_sound.count, 1)
    Equal(client_sounds, 0)
    dedicated = false
    inst.parent = owner
    Repair(inst, Fuel(), owner)
    Equal(client_sounds, 1)
    dedicated = true
end)

Test("client initializes action prediction and delayed sound listener only", function()
    TheWorld.ismastersim = false
    local inst = Entity()
    Configure(inst, { refill_rate = .2 })
    Equal(next(inst.components), nil)
    Equal(inst:HasTag("repairshortaction"), true)
    Equal(inst.events["nightsword_refill.playfuelsound"], nil)
    inst:RunTasks()
    local before = client_sounds
    inst:PushEvent("nightsword_refill.playfuelsound")
    Equal(client_sounds, before)
    inst.parent = { replica = { container = { IsOpenedBy = function() return true end } } }
    inst:PushEvent("nightsword_refill.playfuelsound")
    Equal(client_sounds, before + 1)
    TheWorld.ismastersim = true
end)

Test("night armor uses native repair action and one fuel per repair", function()
    local inst, fuel = NightArmor(), Fuel(5)
    local armor = inst.components.armor
    Equal(HasRepairAction(inst, fuel), false)
    Equal(Repair(inst, fuel), false)
    Equal(fuel.count, 5)
    armor:SetPercent(.85)
    Equal(HasRepairAction(inst, fuel), true)
    Equal(Repair(inst, fuel), true)
    Near(armor:GetPercent(), 1)
    Equal(fuel.count, 4)
    Equal(fuel.consumed, 1)
    Equal(HasRepairAction(inst, fuel), false)
    Equal(Repair(inst, fuel), false)
    Equal(inst.sounds, 1)
    Equal(inst.components.finiteuses, nil)
end)

Test("night armor refill rates and durability multipliers", function()
    for _, rate in ipairs({ .1, .2, .3, .5 }) do
        for _, multiplier in ipairs({ 1, 2, 5 }) do
            local inst = NightArmor({ refill_rate = rate, maximum_use = multiplier })
            local armor = inst.components.armor
            Equal(armor.maxcondition, 525 * multiplier)
            armor:SetPercent(.1)
            Equal(Repair(inst, Fuel()), true)
            Near(armor:GetPercent(), .1 + rate)
        end
    end
end)

Test("night armor rejects wrong material and wrong prefab", function()
    local inst = NightArmor()
    inst.components.armor:SetPercent(.5)
    for _, fuel in ipairs({ Fuel(2, "twigs", MATERIALS.WOOD), Fuel(2, "modded_fuel") }) do
        Equal(Repair(inst, fuel), false)
        Equal(fuel.count, 2)
    end
    local fuel = Fuel()
    fuel.components.stackable = nil
    Equal(Repair(inst, fuel), true)
    Equal(fuel.removed, true)
end)

Test("exhausted night armor is inert and repair restores original attributes", function()
    local inst = NightArmor()
    local armor = inst.components.armor
    for _ = 1, 2 do
        armor:TakeDamage(1000)
        Equal(inst.removed, nil)
        Equal(armor.condition, 0)
        Equal(armor:GetAbsorption(), 0)
        Equal(inst.components.equippable.dapperness, 0)
        Equal(inst.components.shadowlevel.level, 0)
        Equal(HasRepairAction(inst, Fuel()), true)
        Equal(Repair(inst, Fuel()), true)
        Near(armor:GetPercent(), .2)
        Equal(armor:GetAbsorption(), .95)
        Equal(inst.components.equippable.dapperness, -3)
        Equal(inst.components.shadowlevel.level, 2)
    end
end)

Test("night armor retention and refill can be disabled", function()
    local disposable = NightArmor({ wont_break = false })
    disposable.components.armor:TakeDamage(1000)
    Equal(disposable.removed, true)
    local no_refill = NightArmor({ refill_rate = 0 })
    no_refill.components.armor:SetPercent(.5)
    Equal(no_refill.components.repairable, nil)
    Equal(no_refill._refill_sound, nil)
    Equal(HasRepairAction(no_refill, Fuel()), false)
end)

Test("infinite night armor uses native condition loss multiplier", function()
    local inst = NightArmor({ maximum_use = 999 })
    local armor = inst.components.armor
    armor:TakeDamage(200)
    Equal(armor.condition, 525)
    armor:SetPercent(.5)
    Equal(Repair(inst, Fuel()), true)
    Near(armor:GetPercent(), .7)
end)

Test("existing night armor saves including zero survive load and refill", function()
    for _, condition in ipairs({ 0, 123, 525 }) do
        local inst = NightArmor()
        inst.components.armor:OnLoad({ condition = condition })
        inst:RunTasks()
        Equal(inst.components.armor.condition, condition)
        local data = inst.components.armor:OnSave()
        local reloaded = NightArmor()
        if data then reloaded.components.armor:OnLoad(data) end
        reloaded:RunTasks()
        Equal(reloaded.components.armor.condition, condition)
        if condition < 525 then
            Equal(Repair(reloaded, Fuel()), true)
            Equal(reloaded.components.armor:GetAbsorption(), .95)
        end
    end
end)

Test("night armor equipped and inventory sounds plus English speech", function()
    local inst = NightArmor({ english = true })
    local owner = Entity()
    owner.entity:AddSoundEmitter()
    local speech
    owner.components.talker = { Say = function(_, message) speech = message end }
    owner.replica.inventory = { IsOpenedBy = function(_, player) return player == ThePlayer end }
    inst.components.inventoryitem.owner = owner
    inst.components.equippable.equipped = true
    inst.components.armor:SetPercent(.5)
    Equal(Repair(inst, Fuel(), owner), true)
    Equal(speech, "Night Armor durability restored: 20%.")
    Equal(owner.sounds, 1)
    inst.components.equippable.equipped = false
    Equal(Repair(inst, Fuel(), owner), true)
    Equal(inst._refill_sound.count, 1)
    dedicated = false
    inst.parent = owner
    local before = client_sounds
    Equal(Repair(inst, Fuel(), owner), true)
    Equal(client_sounds, before + 1)
    Equal(speech, "Night Armor fully repaired.")
    dedicated = true
end)

Test("night armor client initializes only action and sound networking", function()
    TheWorld.ismastersim = false
    local inst = Entity()
    ConfigureArmor(inst, { refill_rate = .2 })
    Equal(next(inst.components), nil)
    Equal(inst:HasTag("repairshortaction"), true)
    inst:RunTasks()
    local before = client_sounds
    inst.parent = { replica = { container = { IsOpenedBy = function() return true end } } }
    inst:PushEvent("nightarmor_refill.playfuelsound")
    Equal(client_sounds, before + 1)
    TheWorld.ismastersim = true
end)

print(string.format("%d tests passed (native DST components/actions, Lua %s)", passed, _VERSION))
