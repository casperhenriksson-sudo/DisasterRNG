local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpinData = require(ReplicatedStorage:WaitForChild("SpinData"))
local DataManager = require(game.ServerScriptService.DataManager)

local SpinHandler = {}

local function getTotalWeight(tbl)
    local total = 0
    for _, item in ipairs(tbl) do
        total = total + item.weight
    end
    return total
end

local function weightedRandom(tbl, luckMultiplier)
    local adjusted = {}
    for i, item in ipairs(tbl) do
        local newWeight = item.weight
        if i >= 5 then -- Legendary och uppåt bootas av luck
            newWeight = math.max(1, math.floor(item.weight * luckMultiplier))
        end
        table.insert(adjusted, {data = item, weight = newWeight})
    end

    local total = getTotalWeight(adjusted)
    local roll = math.random(1, total)
    local cumulative = 0

    for _, item in ipairs(adjusted) do
        cumulative = cumulative + item.weight
        if roll <= cumulative then
            return item.data
        end
    end
end

local function rollBonus()
    local total = getTotalWeight(SpinData.BonusChances)
    local roll = math.random(1, total + 800)
    if roll > total then return nil end

    local cumulative = 0
    for _, bonus in ipairs(SpinData.BonusChances) do
        cumulative = cumulative + bonus.weight
        if roll <= cumulative then
            return bonus.multiplier
        end
    end
end

function SpinHandler.DoSpin(player, luckMultiplier)
    luckMultiplier = luckMultiplier or 1
    local results = {}

    -- Första spinnen
    local rarity = weightedRandom(SpinData.Rarities, luckMultiplier)
    local brainrotList = SpinData.Brainrots[rarity.name]
    local brainrot = brainrotList[math.random(1, #brainrotList)]

    -- Lås upp i index
    DataManager.UnlockBrainrot(player, brainrot.name)

    table.insert(results, {
        rarity   = rarity.name,
        color    = rarity.color,
        brainrot = brainrot.name,
        perk     = brainrot.perk,
        bonus    = nil,
    })

    -- Bonus-kedja
    local currentLuck = luckMultiplier
    local bonusRoll = rollBonus()

    while bonusRoll ~= nil do
        currentLuck = currentLuck * bonusRoll

        local bonusRarity = weightedRandom(SpinData.Rarities, currentLuck)
        local bonusList = SpinData.Brainrots[bonusRarity.name]
        local bonusBrainrot = bonusList[math.random(1, #bonusList)]

        DataManager.UnlockBrainrot(player, bonusBrainrot.name)

        table.insert(results, {
            rarity   = bonusRarity.name,
            color    = bonusRarity.color,
            brainrot = bonusBrainrot.name,
            perk     = bonusBrainrot.perk,
            bonus    = bonusRoll,
        })

        bonusRoll = rollBonus()
        if currentLuck > 500 then break end
    end

    -- Sätt senaste brainrot som aktiv
    local latestResult = results[#results]
    local data = DataManager.GetData(player)
    if data then
        -- Lägg till i aktiva om det finns plats
        local maxSlots = ({6, 10, 14, 18})[math.min(data.rebirth + 1, 4)]
        if #data.activeBrainrots < maxSlots then
            table.insert(data.activeBrainrots, {
                name = latestResult.brainrot,
                perk = latestResult.perk,
                rarity = latestResult.rarity,
            })
        else
            -- Byt ut den sista
            data.activeBrainrots[#data.activeBrainrots] = {
                name = latestResult.brainrot,
                perk = latestResult.perk,
                rarity = latestResult.rarity,
            }
        end
    end

    return results
end

local function rollRarityWithMinimum(minIndex)
    -- Build adjusted weights: zero out rarities below minIndex
    local adjusted = {}
    for i, r in ipairs(SpinData.Rarities) do
        local w = (i >= minIndex) and r.weight or 0
        table.insert(adjusted, {data=r, weight=w})
    end
    local total = 0
    for _, item in ipairs(adjusted) do total = total + item.weight end
    if total == 0 then return SpinData.Rarities[minIndex] end  -- fallback
    local roll = math.random(1, total)
    local cumulative = 0
    for _, item in ipairs(adjusted) do
        cumulative = cumulative + item.weight
        if roll <= cumulative then return item.data end
    end
    return SpinData.Rarities[minIndex]
end

function SpinHandler.DoTierSpin(player, tierName)
    local tier = SpinData.Tiers[tierName]
    if not tier then return nil end

    local rarity = rollRarityWithMinimum(tier.minRarityIndex)
    local itemPool = SpinData.Items[rarity.name]
    if not itemPool or #itemPool == 0 then
        itemPool = SpinData.Items["Common"]
    end
    local item = itemPool[math.random(1, #itemPool)]

    return {
        rarity    = rarity.name,
        itemName  = item.name,
        itemColor = item.color,
        rarityColor = rarity.color,
    }
end

return SpinHandler
