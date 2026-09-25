local ConfigureNightSword = require("nightsword_refill")

local options = {
    english = GetModConfigData("lang") == true,
    refill_rate = GetModConfigData("refill_rate") or 0.20,
    maximum_use = GetModConfigData("maximum_use") or 1,
    wont_break = GetModConfigData("wont_break") ~= false,
}

AddPrefabPostInit("nightsword", function(inst)
    ConfigureNightSword(inst, options)
end)
