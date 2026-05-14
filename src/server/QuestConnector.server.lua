-- QuestConnector: server endpoints for quest UI (get + claim)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestManager = require(game.ServerScriptService.QuestManager)

local function getOrCreate(name, class)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(class)
    r.Name = name
    r.Parent = ReplicatedStorage
    return r
end

local QuestGetEvent   = getOrCreate("QuestGetEvent",   "RemoteFunction")
local QuestClaimEvent = getOrCreate("QuestClaimEvent", "RemoteFunction")
local QuestUpdateEvent = getOrCreate("QuestUpdateEvent", "RemoteEvent")

QuestGetEvent.OnServerInvoke = function(player)
    return QuestManager.GetQuests(player)
end

QuestClaimEvent.OnServerInvoke = function(player, questIndex)
    if type(questIndex) ~= "number" then
        return { ok = false, error = "bad index type" }
    end
    questIndex = math.floor(questIndex)
    if questIndex < 1 or questIndex > 3 then
        return { ok = false, error = "index out of range" }
    end
    return QuestManager.ClaimQuest(player, questIndex)
end

print("[QuestConnector] Loaded")
