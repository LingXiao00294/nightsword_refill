local ConfigureNightSword = require("nightsword_refill")
local ConfigureNightArmor = require("nightarmor_refill")
local RegisterInsight = require("refill_insight")

local function RefillRate(name)
    local rate = GetModConfigData(name)
    if rate == 0.10 or rate == 0.20 or rate == 0.25 or rate == 0.333 or rate == 0.50 or rate == 1 then
        return rate
    end
    return 0.20
end

local options = {
    language = GetModConfigData("lang"),
    refill_rate = RefillRate("refill_rate"),
    armor_refill_rate = RefillRate("armor_refill_rate"),
    maximum_use = GetModConfigData("maximum_use") or 1,
    wont_break = GetModConfigData("wont_break") ~= false,
}

local armor_options = {
    language = options.language,
    refill_rate = options.armor_refill_rate,
    maximum_use = options.maximum_use,
    wont_break = options.wont_break,
}

AddPrefabPostInit("nightsword", function(inst)
    ConfigureNightSword(inst, options)
end)

AddPrefabPostInit("armor_sanity", function(inst)
    ConfigureNightArmor(inst, armor_options)
end)

-- Runs after all mods initialize so Insight may load before or after this mod.
AddSimPostInit(function()
    RegisterInsight(GLOBAL.Insight, modname, options)
end)
