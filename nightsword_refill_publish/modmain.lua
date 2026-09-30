local ConfigureNightSword = require("nightsword_refill")
local ConfigureNightArmor = require("nightarmor_refill")
local RegisterInsight = require("refill_insight")

local options = {
    language = GetModConfigData("lang"),
    refill_rate = GetModConfigData("refill_rate") or 0.20,
    maximum_use = GetModConfigData("maximum_use") or 1,
    wont_break = GetModConfigData("wont_break") ~= false,
}

AddPrefabPostInit("nightsword", function(inst)
    ConfigureNightSword(inst, options)
end)

AddPrefabPostInit("armor_sanity", function(inst)
    ConfigureNightArmor(inst, options)
end)

-- Runs after all mods initialize so Insight may load before or after this mod.
AddSimPostInit(function()
    RegisterInsight(GLOBAL.Insight, modname, options)
end)
