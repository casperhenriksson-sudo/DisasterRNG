local Players = game:GetService("Players")

local StaminaManager = {}

local MAX_STAMINA = 5
local DRAIN_RATE  = 1      -- per second while active
local REFILL_RATE = 1 / 3  -- per second while idle

local pool = {}  -- [uid] = {stamina=number, sprinting=bool, climbing=bool}

local function get(uid)
    if not pool[uid] then
        pool[uid] = {stamina = MAX_STAMINA, sprinting = false, climbing = false}
    end
    return pool[uid]
end

function StaminaManager.Init(player)
    pool[player.UserId] = {stamina = MAX_STAMINA, sprinting = false, climbing = false}
end

function StaminaManager.Get(player)
    return get(player.UserId).stamina
end

function StaminaManager.SetSprinting(player, on)
    get(player.UserId).sprinting = on
end

function StaminaManager.SetClimbing(player, on)
    get(player.UserId).climbing = on
end

-- Atomic drain: returns new stamina value
function StaminaManager.Drain(player, amount)
    local d = get(player.UserId)
    d.stamina = math.max(0, d.stamina - amount)
    return d.stamina
end

-- Returns true if stamina > threshold (default 0.05)
function StaminaManager.HasStamina(player, threshold)
    return get(player.UserId).stamina > (threshold or 0.05)
end

Players.PlayerRemoving:Connect(function(p) pool[p.UserId] = nil end)

-- Shared drain/refill loop at 10 Hz
task.spawn(function()
    while true do
        task.wait(0.1)
        local dt = 0.1
        for _, d in pairs(pool) do
            local active = d.sprinting or d.climbing
            if active then
                d.stamina = math.max(0, d.stamina - DRAIN_RATE * dt)
            else
                d.stamina = math.min(MAX_STAMINA, d.stamina + REFILL_RATE * dt)
            end
        end
    end
end)

return StaminaManager
