-- CloseCallDetector: server module that detects near-death (health ≤10)
-- and fires CloseCallEvent to the individual player.
-- 3-second cooldown per player to prevent spam.
-- Called via Init() from GameManager.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CloseCallDetector = {}

local closeCallCooldowns = {}  -- [userId] = last trigger time
local COOLDOWN           = 3   -- seconds
local CloseCallEvent     -- RemoteEvent, created in Init()

-- Hook a single player's humanoid for close-call detection
local function hookPlayer(player)
    local function hookChar(char)
        local humanoid = char:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        local prevHealth = humanoid.Health

        humanoid.HealthChanged:Connect(function(newHealth)
            -- Only trigger when crossing from above 10 → to ≤10 (and alive)
            if prevHealth > 10 and newHealth > 0 and newHealth <= 10 then
                local uid = player.UserId
                local now = os.clock()
                if not closeCallCooldowns[uid] or now - closeCallCooldowns[uid] >= COOLDOWN then
                    closeCallCooldowns[uid] = now
                    CloseCallEvent:FireClient(player)
                end
            end
            prevHealth = newHealth
        end)
    end

    if player.Character then
        hookChar(player.Character)
    end
    player.CharacterAdded:Connect(hookChar)
end

function CloseCallDetector.Init()
    -- Create RemoteEvent
    CloseCallEvent = ReplicatedStorage:FindFirstChild("CloseCallEvent")
    if not CloseCallEvent then
        CloseCallEvent = Instance.new("RemoteEvent")
        CloseCallEvent.Name = "CloseCallEvent"
        CloseCallEvent.Parent = ReplicatedStorage
    end

    -- Hook existing players
    for _, player in ipairs(Players:GetPlayers()) do
        hookPlayer(player)
    end

    -- Hook future players
    Players.PlayerAdded:Connect(hookPlayer)

    -- Clean up cooldowns on leave
    Players.PlayerRemoving:Connect(function(player)
        closeCallCooldowns[player.UserId] = nil
    end)

    print("[CloseCallDetector] Initialized")
end

return CloseCallDetector
