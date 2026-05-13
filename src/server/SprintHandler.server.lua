-- SprintHandler  (ServerScriptService)
-- Validates and applies sprint WalkSpeed. Client requests via SprintRequest remote.
-- Server is authoritative: WalkSpeed is never above 24, stamina tracked via StaminaManager.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StaminaManager = require(game.ServerScriptService.StaminaManager)

local BASE_SPEED   = 16
local SPRINT_SPEED = 24

local isSprinting = {}  -- [uid] = bool, mirrors what we requested from StaminaManager

local SprintRequest = ReplicatedStorage:FindFirstChild("SprintRequest")
if not SprintRequest then
    SprintRequest = Instance.new("RemoteEvent")
    SprintRequest.Name = "SprintRequest"
    SprintRequest.Parent = ReplicatedStorage
end

local function setSpeed(player, speed)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = math.clamp(speed, 0, SPRINT_SPEED) end
end

Players.PlayerAdded:Connect(function(player)
    StaminaManager.Init(player)
    player.CharacterAdded:Connect(function()
        StaminaManager.Init(player)
        isSprinting[player.UserId] = false
        task.wait(0.1)
        setSpeed(player, BASE_SPEED)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    isSprinting[player.UserId] = nil
end)

SprintRequest.OnServerEvent:Connect(function(player, on)
    local uid = player.UserId
    if on then
        if StaminaManager.HasStamina(player) then
            isSprinting[uid] = true
            StaminaManager.SetSprinting(player, true)
            setSpeed(player, SPRINT_SPEED)
        end
    else
        isSprinting[uid] = false
        StaminaManager.SetSprinting(player, false)
        setSpeed(player, BASE_SPEED)
    end
end)

-- Stop sprint when stamina runs out
task.spawn(function()
    while true do
        task.wait(0.1)
        for _, player in ipairs(Players:GetPlayers()) do
            local uid = player.UserId
            if isSprinting[uid] and not StaminaManager.HasStamina(player) then
                isSprinting[uid] = false
                StaminaManager.SetSprinting(player, false)
                setSpeed(player, BASE_SPEED)
            end
        end
    end
end)

print("[SprintHandler] Loaded (using StaminaManager)")
