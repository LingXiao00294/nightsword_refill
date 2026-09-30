-- Insight's vanilla repairable descriptor reads the fuel's fixed repair value.
-- Adjust only our equipment's description through its optional public API.
return function(insight, modname, options)
    local api = insight ~= nil and insight.API or nil
    if api == nil or type(api.AddDescriptorPostDescribe) ~= "function"
        or (options.refill_rate <= 0 and options.armor_refill_rate <= 0) then
        return false
    end

    api.AddDescriptorPostDescribe(modname, "repairable", function(repairable, context, descriptions)
        local inst = repairable.inst
        local durability, maximum, current, rate
        if inst.prefab == "nightsword" then
            rate = options.refill_rate
            durability = inst.components.finiteuses
            if durability ~= nil then
                maximum, current = durability.total, durability:GetUses()
            end
        elseif inst.prefab == "armor_sanity" then
            rate = options.armor_refill_rate
            durability = inst.components.armor
            if durability ~= nil then
                maximum, current = durability.maxcondition, durability.condition
            end
        end
        if maximum == nil or maximum <= 0 or current >= maximum or rate <= 0 then
            return
        end

        local inventory = context.player ~= nil and context.player.components.inventory or nil
        local fuel = inventory ~= nil and inventory:GetActiveItem() or nil
        if fuel == nil or fuel.prefab ~= "nightmarefuel" or fuel.components.repairer == nil
            or fuel.components.repairer.repairmaterial ~= repairable.repairmaterial
            or (repairable.testvalidrepairfn ~= nil and not repairable.testvalidrepairfn(inst, fuel)) then
            return
        end
        if repairable.checkmaterialfn ~= nil and not repairable.checkmaterialfn(inst, fuel) then
            return
        end

        local strings = context.lstr ~= nil and context.lstr.repairer or nil
        if strings == nil or strings.held_repair == nil then
            return
        end
        local amount = math.min(maximum * rate, maximum - current)
        descriptions[1] = {
            priority = 0,
            description = string.format(strings.held_repair, fuel.prefab,
                string.format("%g", amount), string.format("%g", amount / maximum * 100)),
        }
    end)
    return true
end
