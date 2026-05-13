local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataManager = require(game.ServerScriptService.DataManager)

local InventoryManager = {}

-- Per-player throttle for GetInventory
local lastInventoryRequest = {}
local INVENTORY_THROTTLE = 5

-- Create remotes
local function getOrCreate(name, class)
    local existing = ReplicatedStorage:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(class)
    r.Name = name
    r.Parent = ReplicatedStorage
    return r
end

local GetInventoryFunc = getOrCreate("GetInventory", "RemoteFunction")
local EquipEvent       = getOrCreate("EquipEvent", "RemoteEvent")
local EquipUpdateEvent = getOrCreate("EquipUpdateEvent", "RemoteEvent")

GetInventoryFunc.OnServerInvoke = function(player)
    local uid = player.UserId
    local now = tick()
    if lastInventoryRequest[uid] and now - lastInventoryRequest[uid] < INVENTORY_THROTTLE then
        return nil  -- throttled
    end
    lastInventoryRequest[uid] = now
    return DataManager.GetInventory(player)
end

EquipEvent.OnServerEvent:Connect(function(player, itemName)
    if type(itemName) ~= "string" then return end

    -- Unequip if same item or empty string
    local current = DataManager.GetEquipped(player)
    if itemName == "" or itemName == current then
        DataManager.SetEquipped(player, nil)
        EquipUpdateEvent:FireAllClients(player, nil)
        return
    end

    -- Validate ownership
    if not DataManager.PlayerOwnsItem(player, itemName) then
        warn("[InventoryManager] " .. player.Name .. " tried to equip unowned item: " .. itemName)
        return
    end

    DataManager.SetEquipped(player, itemName)

    -- Broadcast to all clients so everyone sees the effect
    local inv = DataManager.GetInventory(player)
    local rarityName = inv[itemName] and inv[itemName].rarity or "Common"
    EquipUpdateEvent:FireAllClients(player, itemName, rarityName)
end)

-- When player leaves, clean up throttle
game:GetService("Players").PlayerRemoving:Connect(function(player)
    lastInventoryRequest[player.UserId] = nil
end)

print("[InventoryManager] Loaded")

return InventoryManager
