local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StaminaManager = require(game.ServerScriptService.StaminaManager)

local MovementValidator = {}

-- Constants
local DIVE_COOLDOWN    = 3
local DIVE_IFRAME_DUR  = 1
local MAX_DIVE_FIRES   = 5  -- max fires per DIVE_COOLDOWN window
local CLIMB_MAX_DELTA  = 3.5  -- studs per 0.5s heartbeat
local CLIMB_DRAIN_TICK = 0.5  -- stamina per heartbeat (= 1/sec shared)

-- Per-player state
local diveExpiry   = {}  -- [uid] = cooldown expiry
local iFrameExpiry = {}  -- [uid] = i-frame expiry
local diveFireLog  = {}  -- [uid] = {count, windowStart}
local climbState   = {}  -- [uid] = {lastPos=Vector3, lastTime=number}

local function getOrCreate(name, class)
    local e = ReplicatedStorage:FindFirstChild(name)
    if e then return e end
    local r = Instance.new(class)
    r.Name = name; r.Parent = ReplicatedStorage
    return r
end

local DiveRequest     = getOrCreate("DiveRequest",     "RemoteEvent")
local DiveGranted     = getOrCreate("DiveGranted",     "RemoteEvent")
local ClimbStartEvent = getOrCreate("ClimbStartEvent", "RemoteEvent")
local ClimbHeartbeat  = getOrCreate("ClimbHeartbeat",  "RemoteEvent")
local ClimbStopReq    = getOrCreate("ClimbStopReq",    "RemoteEvent")
local ClimbStopEvent  = getOrCreate("ClimbStopEvent",  "RemoteEvent")

-- ── Dive ──────────────────────────────────────────────────────────────────────

DiveRequest.OnServerEvent:Connect(function(player)
    local uid = player.UserId
    local now = tick()

    -- Rate limit
    local fl = diveFireLog[uid]
    if not fl or now - fl.windowStart > DIVE_COOLDOWN then
        diveFireLog[uid] = {count = 1, windowStart = now}
    else
        fl.count = fl.count + 1
        if fl.count > MAX_DIVE_FIRES then
            warn("[MovementValidator] " .. player.Name .. " dive spam rejected")
            return
        end
    end

    -- Cooldown check
    if diveExpiry[uid] and now < diveExpiry[uid] then return end

    -- Health / state check
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 or hum.Sit then return end

    -- Grant
    diveExpiry[uid]   = now + DIVE_COOLDOWN
    iFrameExpiry[uid] = now + DIVE_IFRAME_DUR
    DiveGranted:FireClient(player, DIVE_COOLDOWN)

    task.delay(DIVE_IFRAME_DUR + 0.1, function()
        if iFrameExpiry[uid] and iFrameExpiry[uid] <= tick() then
            iFrameExpiry[uid] = nil
        end
    end)
end)

function MovementValidator.IsInvulnerable(player)
    local exp = iFrameExpiry[player.UserId]
    return exp ~= nil and tick() < exp
end

-- ── Climb ─────────────────────────────────────────────────────────────────────

ClimbStartEvent.OnServerEvent:Connect(function(player)
    local uid = player.UserId
    local char = player.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return end

    if not StaminaManager.HasStamina(player) then
        ClimbStopEvent:FireClient(player, "no_stamina")
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    climbState[uid] = {lastPos = hrp.Position, lastTime = tick()}
    StaminaManager.SetClimbing(player, true)
end)

ClimbHeartbeat.OnServerEvent:Connect(function(player, reportedPos)
    local uid = player.UserId
    if not climbState[uid] then return end
    if typeof(reportedPos) ~= "Vector3" then return end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        climbState[uid] = nil
        StaminaManager.SetClimbing(player, false)
        return
    end

    local state = climbState[uid]
    local actualPos = hrp.Position

    -- Anti-teleport: check actual server position delta
    local delta = (actualPos - state.lastPos).Magnitude
    if delta > CLIMB_MAX_DELTA then
        warn("[MovementValidator] " .. player.Name .. " climb teleport (delta=" .. string.format("%.1f", delta) .. ")")
        climbState[uid] = nil
        StaminaManager.SetClimbing(player, false)
        ClimbStopEvent:FireClient(player, "teleport")
        return
    end

    -- Surface validation raycast (check 4 horizontal directions)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local dirs = {Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1)}
    local onSurface = false
    for _, d in ipairs(dirs) do
        if workspace:Raycast(actualPos, d * 2.5, params) then
            onSurface = true; break
        end
    end

    if not onSurface then
        climbState[uid] = nil
        StaminaManager.SetClimbing(player, false)
        ClimbStopEvent:FireClient(player, "no_surface")
        return
    end

    -- Drain stamina (shared pool)
    if StaminaManager.Drain(player, CLIMB_DRAIN_TICK) <= 0 then
        climbState[uid] = nil
        StaminaManager.SetClimbing(player, false)
        ClimbStopEvent:FireClient(player, "no_stamina")
        return
    end

    state.lastPos  = actualPos
    state.lastTime = tick()
end)

ClimbStopReq.OnServerEvent:Connect(function(player)
    local uid = player.UserId
    climbState[uid] = nil
    StaminaManager.SetClimbing(player, false)
end)

function MovementValidator.IsClimbing(player)
    return climbState[player.UserId] ~= nil
end

-- Cleanup on respawn
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local uid = player.UserId
        iFrameExpiry[uid] = nil
        diveFireLog[uid]  = nil
        diveExpiry[uid]   = nil
        climbState[uid]   = nil
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    local uid = player.UserId
    iFrameExpiry[uid] = nil
    diveFireLog[uid]  = nil
    diveExpiry[uid]   = nil
    climbState[uid]   = nil
end)

print("[MovementValidator] Loaded")
return MovementValidator
