-- SprintHandler  (ServerScriptService)
-- Validates and applies sprint WalkSpeed. Client requests via SprintRequest remote.
-- Server is authoritative: WalkSpeed is never above 24, stamina tracked server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BASE_SPEED    = 16
local SPRINT_SPEED  = 24   -- 1.5x
local MAX_STAMINA   = 5    -- seconds
local DRAIN_RATE    = 1    -- per second sprinting
local REFILL_RATE   = 1/3  -- per second resting

-- Create or find SprintRequest RemoteEvent
local SprintRequest = ReplicatedStorage:FindFirstChild("SprintRequest")
if not SprintRequest then
    SprintRequest = Instance.new("RemoteEvent")
    SprintRequest.Name = "SprintRequest"
    SprintRequest.Parent = ReplicatedStorage
end

-- Per-player state
local sprintData = {}  -- [userId] = {sprinting=bool, stamina=number}

local function getData(player)
    local uid = player.UserId
    if not sprintData[uid] then
        sprintData[uid] = {sprinting = false, stamina = MAX_STAMINA}
    end
    return sprintData[uid]
end

local function setSpeed(player, speed)
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            -- Cap to sprint speed; never let sprint override perk-based speed reduction
            humanoid.WalkSpeed = math.clamp(speed, 0, SPRINT_SPEED)
        end
    end
end

-- Re-apply speed on respawn
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local data = getData(player)
        data.sprinting = false
        -- Reset to base on respawn
        task.wait(0.1)
        setSpeed(player, BASE_SPEED)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    sprintData[player.UserId] = nil
end)

-- Handle sprint request from client
SprintRequest.OnServerEvent:Connect(function(player, on)
    local data = getData(player)

    if on then
        -- Only allow sprint if stamina > 0
        if data.stamina > 0.05 then
            data.sprinting = true
            setSpeed(player, SPRINT_SPEED)
        end
    else
        data.sprinting = false
        setSpeed(player, BASE_SPEED)
    end
end)

-- Server stamina loop: drain while sprinting, refill when not
task.spawn(function()
    while true do
        task.wait(0.1)  -- 10 Hz
        local dt = 0.1
        for _, player in ipairs(Players:GetPlayers()) do
            local data = sprintData[player.UserId]
            if data then
                if data.sprinting then
                    data.stamina = math.max(0, data.stamina - DRAIN_RATE * dt)
                    if data.stamina <= 0 then
                        data.sprinting = false
                        setSpeed(player, BASE_SPEED)
                    end
                else
                    data.stamina = math.min(MAX_STAMINA, data.stamina + REFILL_RATE * dt)
                end
            end
        end
    end
end)
