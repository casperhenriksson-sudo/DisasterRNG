local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SpinData       = require(ReplicatedStorage:WaitForChild("SpinData"))
local SpinHandler    = require(game.ServerScriptService.SpinHandler)
local PerkManager    = require(game.ServerScriptService.PerkManager)
local CurrencyManager= require(game.ServerScriptService.CurrencyManager)
local DataManager    = require(game.ServerScriptService.DataManager)
local RoundManager   = require(game.ServerScriptService.RoundManager)

-- Old brainrot spin (keep for RoundEnd flow)
local SpinEvent = ReplicatedStorage:WaitForChild("SpinEvent")

-- New tier-based item spin
local function getOrCreate(name, class)
    local e = ReplicatedStorage:FindFirstChild(name)
    if e then return e end
    local r = Instance.new(class)
    r.Name = name
    r.Parent = ReplicatedStorage
    return r
end

local SpinRequestEvent    = getOrCreate("SpinRequestEvent",    "RemoteEvent")
local SpinResultEvent     = getOrCreate("SpinResultEvent",     "RemoteEvent")
local SecretAnnounceEvent = getOrCreate("SecretAnnounceEvent", "RemoteEvent")

-- Per-player cooldown (3 seconds)
local lastSpinTime = {}
local SPIN_COOLDOWN = 3

-- ── Old brainrot spin (RoundEnd) ──────────────────────────────────────────────
SpinEvent.OnServerEvent:Connect(function(player, _ignoredLuck)
    -- Derive luck from server data, never trust client
    local data = DataManager.GetData(player)
    local serverLuck = math.clamp(data and (data.luck or 1) or 1, 1, 5)

    local results = SpinHandler.DoSpin(player, serverLuck)
    SpinEvent:FireClient(player, results)

    local latest = results[#results]
    if latest and latest.perk ~= "???" then
        PerkManager.ApplyPerk(player, latest.perk)
    end

    print("[SpinConnector] " .. player.Name .. " brainrot: " .. results[#results].brainrot .. " (" .. results[#results].rarity .. ")")
end)

-- ── New tier-based item spin ──────────────────────────────────────────────────
SpinRequestEvent.OnServerEvent:Connect(function(player, tierName)
    if type(tierName) ~= "string" then return end

    -- Validate tier exists on server
    local tier = SpinData.Tiers[tierName]
    if not tier then
        SpinResultEvent:FireClient(player, {error="invalid_tier"})
        return
    end

    -- Round check
    if RoundManager.IsRoundActive() then
        SpinResultEvent:FireClient(player, {error="in_round"})
        return
    end

    -- Cooldown check
    local uid = player.UserId
    local now = tick()
    if lastSpinTime[uid] and now - lastSpinTime[uid] < SPIN_COOLDOWN then
        SpinResultEvent:FireClient(player, {error="cooldown"})
        return
    end

    -- Atomic DC deduction
    local spent = CurrencyManager.SpendCoins(player, tier.cost)
    if not spent then
        SpinResultEvent:FireClient(player, {error="insufficient_dc"})
        return
    end

    -- Update cooldown AFTER successful deduction
    lastSpinTime[uid] = now

    -- Roll item
    local result = SpinHandler.DoTierSpin(player, tierName)
    if not result then
        -- Refund on internal error
        CurrencyManager.AwardCoins(player, tier.cost, "spin_refund")
        SpinResultEvent:FireClient(player, {error="internal"})
        return
    end

    -- Add to inventory
    DataManager.AddItem(player, result.itemName, result.rarity)
    result.isNew = true
    result.tier = tierName

    -- Fire result to player
    SpinResultEvent:FireClient(player, result)

    -- SECRET: server-wide announce
    if result.rarity == "Secret" then
        SecretAnnounceEvent:FireAllClients(player.Name, result.itemName)
        print("[SpinConnector] SECRET rolled by " .. player.Name .. "!")
    end

    print("[SpinConnector] " .. player.Name .. " rolled " .. result.rarity .. ": " .. result.itemName .. " (tier: " .. tierName .. ")")
end)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
    lastSpinTime[player.UserId] = nil
end)

print("[SpinConnector] Loaded (brainrot + item spin)")
