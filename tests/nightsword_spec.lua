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
local RegisterInsight = require("refill_insight")
local NativeInsightDescribe
if arg[2] ~= nil then
    Round = function(value, places)
        local scale = 10 ^ places
        return math.floor(value * scale + .5) / scale
    end
    NativeInsightDescribe = assert(loadfile(arg[2].."/scripts/descriptors/repairable.lua"))().Describe
end
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

local function Sword(overrides, configure)
    local inst = Entity()
    inst.prefab = "nightsword"
    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetOnFinished(inst.Remove)
    inst.components.weapon = { inst = inst, damage = 91, SetDamage = function(self, value) self.damage = value end,
        attackwearmultipliers = { Get = function() return 1 end } }
    inst.components.equippable = { dapperness = -7, IsEquipped = function(self) return self.equipped end }
    inst.components.inventoryitem = {}
    inst.components.hauntable = { onhaunt = function() return "launched" end,
        SetOnHauntFn = function(self, fn) self.onhaunt = fn end }
    local options = { refill_rate = .2, maximum_use = 1, wont_break = true, language = "none" }
    for key, value in pairs(overrides or {}) do options[key] = value end
    (configure or Configure)(inst, options)
    return inst
end

local function NightArmor(overrides, configure)
    local inst = Entity()
    inst.prefab = "armor_sanity"
    inst:AddComponent("armor")
    inst.components.armor:InitCondition(525, .95)
    inst.components.equippable = { dapperness = -3, IsEquipped = function(self) return self.equipped end }
    inst.components.shadowlevel = { level = 2, SetDefaultLevel = function(self, value) self.level = value end }
    inst.components.inventoryitem = {}
    local options = { refill_rate = .2, maximum_use = 1, wont_break = true, language = "none" }
    for key, value in pairs(overrides or {}) do options[key] = value end
    (configure or ConfigureArmor)(inst, options)
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
    local env = setmetatable({ GetModConfigData = function() end, AddSimPostInit = function() end,
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

Test("default silence and existing language choices work through mod entry", function()
    local info = {}
    setfenv(assert(loadfile("modinfo.lua")), info)()
    local language
    for _, option in ipairs(info.configuration_options) do
        if option.name == "lang" then language = option end
    end
    Equal(language.default, "none")
    local default_is_selectable = false
    for _, option in ipairs(language.options) do
        if option.data == language.default then default_is_selectable = true end
    end
    Equal(default_is_selectable, true)

    for _, choice in ipairs({ { value = language.default }, { value = false }, { value = true }, {} }) do
        local hooks = {}
        local env = setmetatable({
            AddSimPostInit = function() end,
            GetModConfigData = function(name)
                if name == "lang" then return choice.value end
            end,
            AddPrefabPostInit = function(name, fn) hooks[name] = fn end,
        }, { __index = _G })
        setfenv(assert(loadfile("modmain.lua")), env)()
        local sword = Sword(nil, hooks.nightsword)
        local armor = NightArmor(nil, hooks.armor_sanity)
        local owner, messages = Entity(), {}
        owner.entity:AddSoundEmitter()
        owner.components.talker = { Say = function(_, message) table.insert(messages, message) end }
        for _, inst in ipairs({ sword, armor }) do
            inst.components.inventoryitem.owner = owner
            inst.components.equippable.equipped = true
        end

        sword.components.finiteuses:SetUses(0)
        Equal(Repair(sword, Fuel(), owner), true)
        sword.components.finiteuses:SetUses(90)
        Equal(Repair(sword, Fuel(), owner), true)
        armor.components.armor:SetPercent(.5)
        Equal(Repair(armor, Fuel(), owner), true)
        armor.components.armor:SetPercent(.9)
        Equal(Repair(armor, Fuel(), owner), true)
        Equal(owner.sounds, 4)
        if type(choice.value) == "boolean" then
            local expected = choice.value and {
                "Night Sword durability exhausted.", "Night Sword durability restored: 20%.",
                "Night Sword fully repaired.", "Night Armor durability restored: 20%.",
                "Night Armor fully repaired.",
            } or {
                "暗夜剑耐久度耗尽。", "暗夜剑耐久度恢复：20%。", "暗夜剑完全修复。",
                "暗夜甲耐久度恢复：20%。", "暗夜甲完全修复。",
            }
            Equal(#messages, #expected)
            for i, message in ipairs(expected) do Equal(messages[i], message) end
        else
            Equal(#messages, 0)
        end
    end
end)

Test("Insight integration is optional and registers after mods initialize", function()
    Equal(RegisterInsight(nil, "test", { refill_rate = .2, armor_refill_rate = .2 }), false)
    Equal(RegisterInsight({ API = {} }, "test", { refill_rate = .2, armor_refill_rate = .2 }), false)
    local register_calls = 0
    local insight = { API = { AddDescriptorPostDescribe = function(name, descriptor, callback)
        Equal(name, "test")
        Equal(descriptor, "repairable")
        Equal(type(callback), "function")
        register_calls = register_calls + 1
    end } }
    Equal(RegisterInsight(insight, "test", { refill_rate = 0, armor_refill_rate = 0 }), false)
    local initialize
    local globals = {}
    local env = setmetatable({
        GLOBAL = globals, modname = "test", GetModConfigData = function() end,
        AddPrefabPostInit = function() end,
        AddSimPostInit = function(fn) initialize = fn end,
    }, { __index = _G })
    setfenv(assert(loadfile("modmain.lua")), env)()
    initialize()
    Equal(register_calls, 0)
    globals.Insight = insight
    initialize()
    Equal(register_calls, 1)
end)

local function InsightCallback(rate)
    local callback
    RegisterInsight({ API = { AddDescriptorPostDescribe = function(_, _, fn) callback = fn end } },
        "test", { refill_rate = rate, armor_refill_rate = rate })
    return callback
end

local function InsightDescription(inst, fuel, callback)
    local context = {
        player = { components = { inventory = { GetActiveItem = function() return fuel end } } },
        config = { repair_values = 0 },
        lstr = { repairer = { held_repair = "%s restores %s (%s%%)" } },
    }
    local descriptions = {}
    if NativeInsightDescribe ~= nil then
        descriptions[1] = NativeInsightDescribe(inst.components.repairable, context)
    end
    callback(inst.components.repairable, context, descriptions)
    return descriptions[1]
end

Test("equipment refill menus contain exactly six rates and default to twenty percent", function()
    local info = {}
    setfenv(assert(loadfile("modinfo.lua")), info)()
    local found = 0
    for _, option in ipairs(info.configuration_options) do
        if option.name == "refill_rate" or option.name == "armor_refill_rate" then
            found = found + 1
            Equal(option.default, .2)
            Equal(#option.options, 6)
            for i, rate in ipairs({ .1, .2, .25, .333, .5, 1 }) do
                Equal(option.options[i].data, rate)
                Equal(option.options[i].description, string.format("%g%%", rate * 100))
            end
        end
    end
    Equal(found, 2)
end)

local function RefillEntry(config)
    local hooks, initialize, callback
    hooks = {}
    local env = setmetatable({
        GetModConfigData = function(name) return config[name] end,
        AddPrefabPostInit = function(name, fn) hooks[name] = fn end,
        AddSimPostInit = function(fn) initialize = fn end,
        modname = "test",
        GLOBAL = { Insight = { API = { AddDescriptorPostDescribe = function(_, _, fn) callback = fn end } } },
    }, { __index = _G })
    setfenv(assert(loadfile("modmain.lua")), env)()
    initialize()
    return hooks, callback
end

Test("independent rates drive native repairs speech and Insight through mod entry", function()
    for _, sword_rate in ipairs({ .1, .2, .25, .333, .5, 1 }) do
        for _, armor_rate in ipairs({ .1, .2, .25, .333, .5, 1 }) do
            local hooks, callback = RefillEntry({ refill_rate = sword_rate, armor_refill_rate = armor_rate, lang = true })
            local sword, armor = Sword(nil, hooks.nightsword), NightArmor(nil, hooks.armor_sanity)
            local owner, message = Entity()
            owner.components.talker = { Say = function(_, text) message = text end }
            for _, item in ipairs({ { inst = sword, rate = sword_rate, name = "Night Sword" },
                { inst = armor, rate = armor_rate, name = "Night Armor" } }) do
                local durability = item.inst.components.finiteuses or item.inst.components.armor
                durability:SetPercent(0)
                local maximum = durability.total or durability.maxcondition
                Equal(InsightDescription(item.inst, Fuel(), callback).description,
                    string.format("nightmarefuel restores %g (%g%%)", maximum * item.rate, item.rate * 100))
                Equal(Repair(item.inst, Fuel(), owner), true)
                Near(durability:GetPercent(), item.rate)
                Equal(message, item.rate == 1 and item.name.." fully repaired."
                    or string.format("%s durability restored: %g%%.", item.name, item.rate * 100))
            end
        end
    end
end)

Test("missing and removed legacy rates use defaults independently", function()
    for _, config in ipairs({ {}, { refill_rate = .3, armor_refill_rate = 0 },
        { refill_rate = 0, armor_refill_rate = .3 }, { refill_rate = .5 },
        { refill_rate = .3, armor_refill_rate = .25 } }) do
        local hooks, callback = RefillEntry(config)
        local rates = { config.refill_rate == .5 and .5 or .2, config.armor_refill_rate == .25 and .25 or .2 }
        for i, inst in ipairs({ Sword(nil, hooks.nightsword), NightArmor(nil, hooks.armor_sanity) }) do
            local durability = inst.components.finiteuses or inst.components.armor
            durability:SetPercent(0)
            local maximum = durability.total or durability.maxcondition
            Equal(InsightDescription(inst, Fuel(), callback).description,
                string.format("nightmarefuel restores %g (%g%%)", maximum * rates[i], rates[i] * 100))
            Equal(Repair(inst, Fuel()), true)
            Near(durability:GetPercent(), rates[i])
        end
    end
end)

Test("Insight hints match actual repairs for both equipment types and all configurations", function()
    for _, factory in ipairs({ Sword, NightArmor }) do
        for _, rate in ipairs({ .1, .2, .25, .333, .5, 1 }) do
            local callback = InsightCallback(rate)
            for _, multiplier in ipairs({ 1, 2, 5, 999 }) do
                for _, percent in ipairs({ 0, .1, .95 }) do
                    local inst = factory({ refill_rate = rate, maximum_use = multiplier })
                    local durability = inst.components.finiteuses or inst.components.armor
                    durability:SetPercent(percent)
                    local maximum = durability.total or durability.maxcondition
                    local before = durability:GetPercent() * maximum
                    local amount = math.min(maximum * rate, maximum - before)
                    local fuel = Fuel(2)
                    local description = InsightDescription(inst, fuel, callback)
                    Equal(description.description, string.format("nightmarefuel restores %g (%g%%)",
                        amount, amount / maximum * 100))
                    Equal(fuel.count, 2)
                    Equal(fuel.components.repairer.finiteusesrepairvalue, 25)
                    Equal(Repair(inst, fuel), true)
                    Near(durability:GetPercent() * maximum - before, amount)
                    Equal(fuel.count, 1)
                end
            end
        end
    end
end)

Test("Insight hints reject full equipment and invalid fuel and leave other equipment alone", function()
    local callback = InsightCallback(.2)
    for _, factory in ipairs({ Sword, NightArmor }) do
        local inst = factory()
        Equal(InsightDescription(inst, Fuel(), callback), nil)
        local durability = inst.components.finiteuses or inst.components.armor
        durability:SetPercent(.5)
        Equal(InsightDescription(inst, nil, callback), nil)
        Equal(InsightDescription(inst, Fuel(2, "twigs", MATERIALS.WOOD), callback), nil)
        Equal(InsightDescription(inst, Fuel(2, "modded_fuel"), callback), nil)
        inst.components.repairable.checkmaterialfn = function() return false end
        Equal(InsightDescription(inst, Fuel(), callback), nil)
    end
    local inst = Sword()
    inst.prefab = "orangeamulet"
    local original = { description = "unmodified" }
    local descriptions = { original }
    callback(inst.components.repairable, {}, descriptions)
    Equal(descriptions[1], original)
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
    for _, rate in ipairs({ .1, .2, .25, .333, .5, 1 }) do
        for _, multiplier in ipairs({ 1, 2, 5 }) do
            local inst = Sword({ refill_rate = rate, maximum_use = multiplier })
            Equal(inst.components.finiteuses.total, 100 * multiplier)
            inst.components.finiteuses:SetPercent(.1)
            Equal(Repair(inst, Fuel()), true)
            Near(inst.components.finiteuses:GetPercent(), math.min(1, .1 + rate))
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
    local inst = Sword({ language = true })
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
    for _, rate in ipairs({ .1, .2, .25, .333, .5, 1 }) do
        for _, multiplier in ipairs({ 1, 2, 5 }) do
            local inst = NightArmor({ refill_rate = rate, maximum_use = multiplier })
            local armor = inst.components.armor
            Equal(armor.maxcondition, 525 * multiplier)
            armor:SetPercent(.1)
            Equal(Repair(inst, Fuel()), true)
            Near(armor:GetPercent(), math.min(1, .1 + rate))
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
    local inst = NightArmor({ language = true })
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
