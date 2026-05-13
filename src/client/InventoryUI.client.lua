-- InventoryUI — shows player's item inventory with equip buttons
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GetInventory = ReplicatedStorage:WaitForChild("GetInventory", 15)
local EquipEvent   = ReplicatedStorage:WaitForChild("EquipEvent",   15)
local EquipUpdateEvent = ReplicatedStorage:WaitForChild("EquipUpdateEvent", 15)
local RoundEvent   = ReplicatedStorage:WaitForChild("RoundEvent",   15)

local RARITY_ORDER = {"Common","Uncommon","Rare","Epic","Legendary","Mythical","Divine","Corrupted","Celestial","Secret"}
local RARITY_COLOR = {
    Common=Color3.fromRGB(200,200,200),Uncommon=Color3.fromRGB(80,200,80),
    Rare=Color3.fromRGB(60,120,255),Epic=Color3.fromRGB(160,60,255),
    Legendary=Color3.fromRGB(255,200,0),Mythical=Color3.fromRGB(255,50,50),
    Divine=Color3.fromRGB(0,220,255),Corrupted=Color3.fromRGB(80,0,120),
    Celestial=Color3.fromRGB(255,100,255),Secret=Color3.fromRGB(255,255,255),
}
local RARITY_PERCENT = {
    Common="45%",Uncommon="25%",Rare="15%",Epic="8%",Legendary="3.5%",
    Mythical="1.5%",Divine="0.8%",Corrupted="0.15%",Celestial="0.04%",Secret="0.01%"
}

local currentEquipped = nil
local isOpen = false
local inRound = false

-- ── ScreenGui ──────────────────────────────────────────────────────────────────
local invGui = Instance.new("ScreenGui")
invGui.Name="InventoryGui"; invGui.ResetOnSpawn=false; invGui.DisplayOrder=15; invGui.Parent=playerGui

-- Inventory button (bottom-right of lobby HUD area)
local invBtn = Instance.new("TextButton")
invBtn.Name="InventoryBtn"
invBtn.Size=UDim2.new(0,140,0,44)
invBtn.Position=UDim2.new(1,-155,1,-120)
invBtn.BackgroundColor3=Color3.fromRGB(30,30,50)
invBtn.BorderSizePixel=0; invBtn.Font=Enum.Font.GothamBold
invBtn.TextSize=14; invBtn.Text="Inventory"; invBtn.TextColor3=Color3.new(1,1,1)
invBtn.Parent=invGui
Instance.new("UICorner",invBtn).CornerRadius=UDim.new(0,10)

-- Main panel
local panel = Instance.new("Frame")
panel.Name="InvPanel"
panel.Size=UDim2.new(0,360,0,500)
panel.Position=UDim2.new(0.5,-180,0.5,-250)
panel.BackgroundColor3=Color3.fromRGB(12,12,22)
panel.BackgroundTransparency=0.05; panel.BorderSizePixel=0
panel.Visible=false; panel.ZIndex=10; panel.Parent=invGui
Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size=UDim2.new(1,0,0,48); titleBar.BackgroundColor3=Color3.fromRGB(30,20,60)
titleBar.BorderSizePixel=0; titleBar.ZIndex=11; titleBar.Parent=panel
Instance.new("UICorner",titleBar).CornerRadius=UDim.new(0,16)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size=UDim2.new(1,-50,1,0); titleLabel.Position=UDim2.new(0,16,0,0)
titleLabel.BackgroundTransparency=1; titleLabel.Font=Enum.Font.GothamBlack
titleLabel.TextSize=18; titleLabel.Text="INVENTORY"; titleLabel.TextColor3=Color3.new(1,1,1)
titleLabel.TextXAlignment=Enum.TextXAlignment.Left; titleLabel.ZIndex=12; titleLabel.Parent=titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size=UDim2.new(0,36,0,36); closeBtn.Position=UDim2.new(1,-42,0,6)
closeBtn.BackgroundColor3=Color3.fromRGB(200,60,60); closeBtn.BorderSizePixel=0
closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=16; closeBtn.Text="X"
closeBtn.TextColor3=Color3.new(1,1,1); closeBtn.ZIndex=12; closeBtn.Parent=titleBar
Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,8)

-- Scroll frame
local scroll = Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-16,1,-60); scroll.Position=UDim2.new(0,8,0,54)
scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0
scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.ScrollBarThickness=4; scroll.ScrollBarImageColor3=Color3.fromRGB(100,100,160)
scroll.ZIndex=11; scroll.Parent=panel

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder=Enum.SortOrder.LayoutOrder; scrollLayout.Padding=UDim.new(0,4)
scrollLayout.Parent=scroll

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingLeft=UDim.new(0,4); scrollPad.PaddingRight=UDim.new(0,4)
scrollPad.PaddingTop=UDim.new(0,4); scrollPad.Parent=scroll

local equippedButtons = {}  -- itemName -> button reference

local function refreshInventory()
    -- Clear existing rows
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
    end
    equippedButtons = {}

    local inv = GetInventory and GetInventory:InvokeServer()
    if not inv or next(inv) == nil then
        local empty = Instance.new("TextLabel")
        empty.Size=UDim2.new(1,0,0,60); empty.BackgroundTransparency=1
        empty.Font=Enum.Font.Gotham; empty.TextSize=14
        empty.Text="No items yet.\nSpin to collect!"; empty.TextColor3=Color3.fromRGB(140,140,160)
        empty.ZIndex=12; empty.Parent=scroll
        return
    end

    -- Group by rarity
    local grouped = {}
    for itemName, itemData in pairs(inv) do
        local r = itemData.rarity or "Common"
        if not grouped[r] then grouped[r] = {} end
        table.insert(grouped[r], {name=itemName, data=itemData})
    end

    -- Render in rarity order
    local layoutOrder = 0
    for _, rarityName in ipairs(RARITY_ORDER) do
        local items = grouped[rarityName]
        if not items then continue end

        -- Rarity header
        local header = Instance.new("Frame")
        header.Size=UDim2.new(1,0,0,26); header.BackgroundColor3=RARITY_COLOR[rarityName] or Color3.fromRGB(100,100,100)
        header.BackgroundTransparency=0.6; header.BorderSizePixel=0; header.LayoutOrder=layoutOrder; layoutOrder=layoutOrder+1
        header.ZIndex=12; header.Parent=scroll
        Instance.new("UICorner",header).CornerRadius=UDim.new(0,6)
        local hLabel=Instance.new("TextLabel")
        hLabel.Size=UDim2.new(1,-80,1,0); hLabel.Position=UDim2.new(0,8,0,0)
        hLabel.BackgroundTransparency=1; hLabel.Font=Enum.Font.GothamBold
        hLabel.TextSize=13; hLabel.Text=rarityName.." ("..RARITY_PERCENT[rarityName]..")"
        hLabel.TextColor3=Color3.new(1,1,1); hLabel.TextXAlignment=Enum.TextXAlignment.Left
        hLabel.ZIndex=13; hLabel.Parent=header
        local hCount=Instance.new("TextLabel")
        hCount.Size=UDim2.new(0,60,1,0); hCount.Position=UDim2.new(1,-64,0,0)
        hCount.BackgroundTransparency=1; hCount.Font=Enum.Font.Gotham
        hCount.TextSize=12; hCount.Text=#items.." items"; hCount.TextColor3=Color3.fromRGB(200,200,200)
        hCount.TextXAlignment=Enum.TextXAlignment.Right; hCount.ZIndex=13; hCount.Parent=header

        -- Sort items alphabetically
        table.sort(items, function(a,b) return a.name<b.name end)

        for _, itemInfo in ipairs(items) do
            local row = Instance.new("Frame")
            row.Size=UDim2.new(1,0,0,44); row.BackgroundColor3=Color3.fromRGB(25,25,42)
            row.BackgroundTransparency=0.4; row.BorderSizePixel=0; row.LayoutOrder=layoutOrder; layoutOrder=layoutOrder+1
            row.ZIndex=12; row.Parent=scroll
            Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)

            -- Color dot
            local dot=Instance.new("Frame")
            dot.Size=UDim2.new(0,18,0,18); dot.Position=UDim2.new(0,8,0.5,-9)
            dot.BackgroundColor3=RARITY_COLOR[rarityName] or Color3.fromRGB(200,200,200)
            dot.BorderSizePixel=0; dot.ZIndex=13; dot.Parent=row
            Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)

            -- Item name
            local nameL=Instance.new("TextLabel")
            nameL.Size=UDim2.new(1,-140,0,22); nameL.Position=UDim2.new(0,34,0,4)
            nameL.BackgroundTransparency=1; nameL.Font=Enum.Font.GothamBold
            nameL.TextSize=13; nameL.Text=itemInfo.name
            nameL.TextColor3=Color3.new(1,1,1); nameL.TextXAlignment=Enum.TextXAlignment.Left
            nameL.ZIndex=13; nameL.Parent=row

            -- Count
            local countL=Instance.new("TextLabel")
            countL.Size=UDim2.new(1,-140,0,16); countL.Position=UDim2.new(0,34,0,24)
            countL.BackgroundTransparency=1; countL.Font=Enum.Font.Gotham
            countL.TextSize=11; countL.Text="x"..tostring(itemInfo.data.count or 1)
            countL.TextColor3=Color3.fromRGB(160,160,180); countL.TextXAlignment=Enum.TextXAlignment.Left
            countL.ZIndex=13; countL.Parent=row

            -- Equip button
            local isEquipped = (currentEquipped == itemInfo.name)
            local equipBtn=Instance.new("TextButton")
            equipBtn.Size=UDim2.new(0,80,0,30); equipBtn.Position=UDim2.new(1,-90,0.5,-15)
            equipBtn.BackgroundColor3=isEquipped and Color3.fromRGB(60,180,60) or Color3.fromRGB(60,60,120)
            equipBtn.BorderSizePixel=0; equipBtn.Font=Enum.Font.GothamBold
            equipBtn.TextSize=12; equipBtn.Text=isEquipped and "Equipped" or "Equip"
            equipBtn.TextColor3=Color3.new(1,1,1); equipBtn.ZIndex=13; equipBtn.Parent=row
            Instance.new("UICorner",equipBtn).CornerRadius=UDim.new(0,6)

            equippedButtons[itemInfo.name] = equipBtn

            local capturedName = itemInfo.name
            equipBtn.MouseButton1Click:Connect(function()
                if currentEquipped == capturedName then
                    EquipEvent:FireServer("")  -- unequip
                else
                    EquipEvent:FireServer(capturedName)
                end
            end)
        end
    end
end

local function openInventory()
    if isOpen then return end
    isOpen = true
    panel.Visible = true
    task.spawn(refreshInventory)
end

local function closeInventory()
    isOpen = false
    panel.Visible = false
end

invBtn.MouseButton1Click:Connect(function()
    if isOpen then closeInventory() else openInventory() end
end)
closeBtn.MouseButton1Click:Connect(closeInventory)

-- Equip update from server
EquipUpdateEvent.OnClientEvent:Connect(function(equippedPlayer, itemName, rarityName)
    if equippedPlayer == player then
        currentEquipped = itemName  -- nil if unequipped
        -- Update button states without full refresh
        for name, btn in pairs(equippedButtons) do
            btn.Text = (name == itemName) and "Equipped" or "Equip"
            btn.BackgroundColor3 = (name == itemName) and Color3.fromRGB(60,180,60) or Color3.fromRGB(60,60,120)
        end
    end
end)

-- Round visibility
RoundEvent.OnClientEvent:Connect(function(ev)
    if ev=="RoundStart" then
        inRound=true; invBtn.Visible=false; closeInventory()
    elseif ev=="RoundEnd" or ev=="LobbyWaiting" then
        inRound=false; invBtn.Visible=true
    end
end)

print("[InventoryUI] Loaded")
