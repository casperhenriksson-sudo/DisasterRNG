-- MomentBroadcaster: server-side broadcast of notable viral moments
-- 1-second minimum gap between broadcasts (anti-spam).
-- Clients receive a plain string message via MomentEvent RemoteEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MomentBroadcaster = {}

local MomentEvent        -- RemoteEvent, created in Init()
local lastBroadcastTime  = 0

local MOMENT_TEMPLATES = {
    CloseCall     = "⚡ {name} barely survived!",
    LastSurvivor  = "👑 {name} is the last survivor!",
    StreakRecord  = "🔥 {name} set a new {type} record: {count}!",
    Win           = "🏆 {name} survived the {disaster}!",
}

local function getOrCreate(name)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new("RemoteEvent")
    r.Name   = name
    r.Parent = ReplicatedStorage
    return r
end

function MomentBroadcaster.Init()
    MomentEvent        = getOrCreate("MomentEvent")
    lastBroadcastTime  = 0
    print("[MomentBroadcaster] Initialized")
end

-- Broadcast a moment to all clients.
-- momentType: one of "CloseCall", "LastSurvivor", "StreakRecord", "Win"
-- data: table with fields used in template ({name, type, count, disaster})
function MomentBroadcaster.Broadcast(momentType, data)
    if not MomentEvent then return end

    -- 1-second minimum gap between broadcasts
    local now = os.clock()
    if now - lastBroadcastTime < 1 then return end
    lastBroadcastTime = now

    local template = MOMENT_TEMPLATES[momentType]
    if not template then
        warn("[MomentBroadcaster] Unknown momentType: " .. tostring(momentType))
        return
    end

    -- Fill template placeholders
    local message = template
    if data then
        message = message:gsub("{name}",     tostring(data.name    or ""))
        message = message:gsub("{type}",     tostring(data.type    or ""))
        message = message:gsub("{count}",    tostring(data.count   or ""))
        message = message:gsub("{disaster}", tostring(data.disaster or ""))
    end

    MomentEvent:FireAllClients(message)
end

return MomentBroadcaster
