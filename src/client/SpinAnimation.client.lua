-- SpinAnimation LocalScript — handles both brainrot (RoundEnd) and item (button) spins

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RoundEvent      = ReplicatedStorage:WaitForChild("RoundEvent")
local SpinEvent       = ReplicatedStorage:WaitForChild("SpinEvent")
local SpinResultEvent = ReplicatedStorage:WaitForChild("SpinResultEvent", 15)
local SecretAnnounceEvent = ReplicatedStorage:WaitForChild("SecretAnnounceEvent", 15)

-- Rarity color lookup
local RARITY_COLOR = {
    Common    = Color3.fromRGB(200,200,200),
    Uncommon  = Color3.fromRGB(80,200,80),
    Rare      = Color3.fromRGB(60,120,255),
    Epic      = Color3.fromRGB(160,60,255),
    Legendary = Color3.fromRGB(255,200,0),
    Mythical  = Color3.fromRGB(255,50,50),
    Divine    = Color3.fromRGB(0,220,255),
    Corrupted = Color3.fromRGB(80,0,120),
    Celestial = Color3.fromRGB(255,100,255),
    Secret    = Color3.fromRGB(255,255,255),
}
local RARITY_LIST = {"Common","Uncommon","Rare","Epic","Legendary","Mythical","Divine","Corrupted","Celestial","Secret"}
local MYSTERY_RARITIES = {Divine=true,Corrupted=true,Celestial=true,Secret=true}
local SPIN_SPEEDS = {0.06,0.06,0.07,0.08,0.10,0.13,0.17,0.22,0.30,0.42,0.58}

local function tw(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

-- ══════════════════════════════════════════════════════════════════════════════
-- OLD BRAINROT SPIN SYSTEM (RoundEnd) — uses SpinFrame in GameUI
-- ══════════════════════════════════════════════════════════════════════════════
local gameUI    = playerGui:WaitForChild("GameUI", 15)
local spinFrame = gameUI and gameUI:FindFirstChild("SpinFrame")

if spinFrame then
    local labelRarity   = spinFrame:FindFirstChild("Rarity")
    local labelBrainrot = spinFrame:FindFirstChild("Brainrot")
    local labelPerk     = spinFrame:FindFirstChild("Perk")
    local labelBonus    = spinFrame:FindFirstChild("BonusLabel")

    local spinGui2 = Instance.new("ScreenGui")
    spinGui2.Name = "SpinAnimGui"; spinGui2.DisplayOrder=50; spinGui2.ResetOnSpawn=false; spinGui2.Parent=playerGui
    local dimFrame = Instance.new("Frame")
    dimFrame.Size=UDim2.fromScale(1,1); dimFrame.BackgroundColor3=Color3.new(0,0,0)
    dimFrame.BackgroundTransparency=1; dimFrame.BorderSizePixel=0; dimFrame.ZIndex=5; dimFrame.Parent=spinGui2

    local pendingResults = nil
    local isAnimating = false
    local activeThread = nil
    local luckMultiplier = 1

    local function resetLabels()
        if labelRarity  then labelRarity.Text="";  labelRarity.TextTransparency=0 end
        if labelBrainrot then labelBrainrot.Text=""; labelBrainrot.TextTransparency=1 end
        if labelPerk    then labelPerk.Text="";    labelPerk.TextTransparency=1 end
        if labelBonus   then labelBonus.Text="";   labelBonus.TextTransparency=1; labelBonus.Visible=false end
    end

    local function setSlot(name, color)
        spinFrame.BackgroundColor3=color; spinFrame.BackgroundTransparency=0.25
        if labelRarity then labelRarity.Text=name end
    end

    local function runSlot(resultRarity, resultColor)
        for i=1,14 do
            local r=RARITY_LIST[math.random(1,#RARITY_LIST)]
            setSlot(r, RARITY_COLOR[r] or Color3.fromRGB(200,200,200)); task.wait(0.06)
        end
        for i,delay in ipairs(SPIN_SPEEDS) do
            local name,color
            if i==#SPIN_SPEEDS then name=resultRarity;color=resultColor
            else local r=RARITY_LIST[math.random(1,#RARITY_LIST)]; name=r; color=RARITY_COLOR[r] or Color3.fromRGB(200,200,200) end
            setSlot(name,color); task.wait(delay)
        end
    end

    local function animateBrainrotResults(results)
        isAnimating=true
        for i,result in ipairs(results) do
            local rn=result.rarity or "Common"
            local rc=RARITY_COLOR[rn] or Color3.fromRGB(200,200,200)
            if i>1 then
                if labelBrainrot then labelBrainrot.TextTransparency=1 end
                if labelPerk then labelPerk.TextTransparency=1 end
                if labelBonus then labelBonus.Visible=false end
                task.wait(0.25)
                runSlot(rn,rc)
            end
            if MYSTERY_RARITIES[rn] then
                if labelRarity then labelRarity.Text="???" end
                spinFrame.BackgroundColor3=Color3.fromRGB(20,0,30); spinFrame.BackgroundTransparency=0.1
                tw(dimFrame,TweenInfo.new(0.35,Enum.EasingStyle.Quad),{BackgroundTransparency=0.45})
                task.wait(0.8)
                tw(dimFrame,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{BackgroundTransparency=1})
            end
            spinFrame.BackgroundColor3=rc; spinFrame.BackgroundTransparency=0.15
            if labelRarity then labelRarity.Text=rn end
            task.wait(0.5)
            if labelBrainrot then labelBrainrot.Text=result.brainrot or ""; labelBrainrot.TextTransparency=0 end
            task.wait(0.3)
            if labelPerk and result.perk and result.perk~="" and result.perk~="???" then
                labelPerk.Text=result.perk; labelPerk.TextTransparency=0
            end
            if result.bonus then
                task.wait(0.15)
                if labelBonus then labelBonus.Text="BONUS x"..result.bonus.."!"; labelBonus.Visible=true; labelBonus.TextTransparency=0 end
            end
            task.wait(2)
        end
        tw(spinFrame,TweenInfo.new(0.55,Enum.EasingStyle.Back,Enum.EasingDirection.In),
            {Position=UDim2.new(spinFrame.Position.X.Scale,spinFrame.Position.X.Offset,spinFrame.Position.Y.Scale,spinFrame.Position.Y.Offset+350),BackgroundTransparency=0.8})
        task.wait(0.6); spinFrame.Visible=false; spinFrame.BackgroundTransparency=0.2
        isAnimating=false
    end

    RoundEvent.OnClientEvent:Connect(function(ev, data)
        if ev=="RoundEnd" then
            if type(data)=="table" and data.luckBonus then luckMultiplier=data.luckBonus end
            task.defer(function()
                if activeThread then task.cancel(activeThread); activeThread=nil; isAnimating=false end
                activeThread=task.spawn(function()
                    spinFrame.Visible=true; resetLabels()
                    SpinEvent:FireServer(luckMultiplier)
                    pendingResults=nil
                    for _=1,8 do local r=RARITY_LIST[math.random(1,#RARITY_LIST)]; setSlot(r,RARITY_COLOR[r] or Color3.fromRGB(200,200,200)); task.wait(0.06) end
                    local t0=os.clock()
                    while pendingResults==nil do task.wait(0.03); if os.clock()-t0>8 then spinFrame.Visible=false; return end end
                    local res=pendingResults; pendingResults=nil
                    local fr=res[1] and res[1].rarity or "Common"
                    runSlot(fr, RARITY_COLOR[fr] or Color3.fromRGB(200,200,200))
                    animateBrainrotResults(res)
                    activeThread=nil
                end)
            end)
        end
    end)

    SpinEvent.OnClientEvent:Connect(function(payload)
        if type(payload)~="table" then return end
        pendingResults=payload
    end)

    spinFrame.Visible=false; resetLabels()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- NEW ITEM SPIN SYSTEM (button-triggered) — fullscreen overlay
-- ══════════════════════════════════════════════════════════════════════════════
local itemSpinGui = Instance.new("ScreenGui")
itemSpinGui.Name = "ItemSpinGui"
itemSpinGui.DisplayOrder = 60
itemSpinGui.ResetOnSpawn = false
itemSpinGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
itemSpinGui.Parent = playerGui

-- Fullscreen dim
local itemDim = Instance.new("Frame")
itemDim.Size=UDim2.fromScale(1,1); itemDim.BackgroundColor3=Color3.new(0,0,0)
itemDim.BackgroundTransparency=1; itemDim.BorderSizePixel=0; itemDim.ZIndex=1; itemDim.Parent=itemSpinGui

-- Main card
local itemCard = Instance.new("Frame")
itemCard.Name="ItemCard"
itemCard.Size=UDim2.new(0,340,0,200)
itemCard.Position=UDim2.new(0.5,-170,0.5,-100)
itemCard.BackgroundColor3=Color3.fromRGB(20,20,35)
itemCard.BackgroundTransparency=1  -- starts hidden
itemCard.BorderSizePixel=0; itemCard.ZIndex=2; itemCard.Parent=itemSpinGui
Instance.new("UICorner",itemCard).CornerRadius=UDim.new(0,18)

local rarityLabel = Instance.new("TextLabel")
rarityLabel.Size=UDim2.new(1,0,0,50); rarityLabel.Position=UDim2.new(0,0,0,20)
rarityLabel.BackgroundTransparency=1; rarityLabel.Font=Enum.Font.GothamBlack
rarityLabel.TextSize=28; rarityLabel.Text=""; rarityLabel.TextColor3=Color3.new(1,1,1)
rarityLabel.TextTransparency=1; rarityLabel.ZIndex=3; rarityLabel.Parent=itemCard

local itemLabel = Instance.new("TextLabel")
itemLabel.Size=UDim2.new(1,-20,0,40); itemLabel.Position=UDim2.new(0,10,0,80)
itemLabel.BackgroundTransparency=1; itemLabel.Font=Enum.Font.GothamBold
itemLabel.TextSize=20; itemLabel.Text=""; itemLabel.TextColor3=Color3.fromRGB(220,220,220)
itemLabel.TextTransparency=1; itemLabel.ZIndex=3; itemLabel.Parent=itemCard

local tapLabel = Instance.new("TextLabel")
tapLabel.Size=UDim2.new(1,0,0,24); tapLabel.Position=UDim2.new(0,0,1,-34)
tapLabel.BackgroundTransparency=1; tapLabel.Font=Enum.Font.Gotham
tapLabel.TextSize=12; tapLabel.Text="Click to close"; tapLabel.TextColor3=Color3.fromRGB(160,160,160)
tapLabel.TextTransparency=1; tapLabel.ZIndex=3; tapLabel.Parent=itemCard

local closeBtn = Instance.new("TextButton")
closeBtn.Size=UDim2.fromScale(1,1); closeBtn.Position=UDim2.fromScale(0,0)
closeBtn.BackgroundTransparency=1; closeBtn.Text=""; closeBtn.ZIndex=10
closeBtn.Parent=itemSpinGui

local itemAnimating = false

local function hideItemSpin()
    tw(itemCard,TweenInfo.new(0.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{BackgroundTransparency=1,Size=UDim2.new(0,300,0,160),Position=UDim2.new(0.5,-150,0.5,-80)})
    tw(itemDim,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{BackgroundTransparency=1})
    tw(rarityLabel,TweenInfo.new(0.2),{TextTransparency=1})
    tw(itemLabel,TweenInfo.new(0.2),{TextTransparency=1})
    tw(tapLabel,TweenInfo.new(0.2),{TextTransparency=1})
    task.delay(0.35, function() itemAnimating=false end)
end

closeBtn.MouseButton1Click:Connect(function()
    if itemAnimating then hideItemSpin() end
end)

local function doItemSpinAnimation(result)
    if itemAnimating then return end
    itemAnimating=true

    local rarity = result.rarity or "Common"
    local rarityColor = result.rarityColor or RARITY_COLOR[rarity] or Color3.fromRGB(200,200,200)
    local itemName = result.itemName or "Unknown"

    -- Reset
    itemCard.BackgroundColor3=Color3.fromRGB(20,20,35)
    itemCard.BackgroundTransparency=1
    itemCard.Size=UDim2.new(0,340,0,200)
    itemCard.Position=UDim2.new(0.5,-170,0.5,-100)
    rarityLabel.Text=""; rarityLabel.TextTransparency=1; rarityLabel.TextColor3=Color3.new(1,1,1)
    itemLabel.Text=""; itemLabel.TextTransparency=1
    tapLabel.TextTransparency=1

    -- Dim + show card
    tw(itemDim,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{BackgroundTransparency=0.5})
    task.wait(0.15)
    tw(itemCard,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{BackgroundTransparency=0.1})
    task.wait(0.2)

    -- Slot machine on rarity label
    for i=1,14 do
        local r=RARITY_LIST[math.random(1,#RARITY_LIST)]
        rarityLabel.Text=r; rarityLabel.TextColor3=RARITY_COLOR[r] or Color3.fromRGB(200,200,200)
        rarityLabel.TextTransparency=0; itemCard.BackgroundColor3=RARITY_COLOR[r] or Color3.fromRGB(20,20,35)
        task.wait(0.07)
    end
    for i,delay in ipairs(SPIN_SPEEDS) do
        local name,color
        if i==#SPIN_SPEEDS then name=rarity;color=rarityColor
        else local r=RARITY_LIST[math.random(1,#RARITY_LIST)]; name=r; color=RARITY_COLOR[r] or Color3.fromRGB(200,200,200) end
        rarityLabel.Text=name; rarityLabel.TextColor3=color; itemCard.BackgroundColor3=color
        task.wait(delay)
    end

    -- Mystery suspense
    if MYSTERY_RARITIES[rarity] then
        rarityLabel.Text="???"; rarityLabel.TextColor3=Color3.fromRGB(180,0,255)
        itemCard.BackgroundColor3=Color3.fromRGB(20,0,30)
        tw(itemDim,TweenInfo.new(0.3),{BackgroundTransparency=0.7})
        -- Screen shake
        for _=1,6 do
            local dx,dy=math.random(-8,8),math.random(-6,6)
            itemCard.Position=UDim2.new(0.5,-170+dx,0.5,-100+dy); task.wait(0.08)
        end
        itemCard.Position=UDim2.new(0.5,-170,0.5,-100)
        task.wait(0.4)
        -- Flash
        local flash=Instance.new("Frame")
        flash.Size=UDim2.fromScale(1,1); flash.BackgroundColor3=Color3.new(1,1,1)
        flash.BackgroundTransparency=0.2; flash.BorderSizePixel=0; flash.ZIndex=20; flash.Parent=itemSpinGui
        tw(flash,TweenInfo.new(0.3,Enum.EasingStyle.Quad),{BackgroundTransparency=1}).Completed:Connect(function() flash:Destroy() end)
        tw(itemDim,TweenInfo.new(0.3),{BackgroundTransparency=0.5})
    end

    -- Reveal rarity
    rarityLabel.Text=rarity; rarityLabel.TextColor3=rarityColor
    itemCard.BackgroundColor3=rarityColor
    tw(rarityLabel,TweenInfo.new(0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{TextTransparency=0})
    task.wait(0.5)

    -- Reveal item name
    itemLabel.Text=itemName
    tw(itemLabel,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{TextTransparency=0})
    task.wait(0.5)
    tw(tapLabel,TweenInfo.new(0.3),{TextTransparency=0})

    -- For Legendary+: gold border pulse
    local tierIndex = 1
    for i,r in ipairs(RARITY_LIST) do if r==rarity then tierIndex=i; break end end
    if tierIndex >= 5 then  -- Legendary+
        local stroke = Instance.new("UIStroke")
        stroke.Color=rarityColor; stroke.Thickness=4; stroke.Parent=itemCard
        tw(stroke,TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,4,true),{Thickness=8})
        task.delay(4, function() if stroke.Parent then stroke:Destroy() end end)
    end

    -- Auto-close after 5 seconds
    task.delay(5, function()
        if itemAnimating then hideItemSpin() end
    end)
end

SpinResultEvent.OnClientEvent:Connect(function(result)
    if type(result)~="table" then return end
    if result.error then return end  -- SpinUI handles errors
    task.spawn(function()
        doItemSpinAnimation(result)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- SECRET server-wide announcement
-- ══════════════════════════════════════════════════════════════════════════════
SecretAnnounceEvent.OnClientEvent:Connect(function(rollerName, itemName)
    -- Create a dramatic full-screen banner
    local announceGui = Instance.new("ScreenGui")
    announceGui.Name="SecretAnnounceGui"; announceGui.DisplayOrder=200; announceGui.ResetOnSpawn=false; announceGui.Parent=playerGui

    local banner = Instance.new("Frame")
    banner.Size=UDim2.new(1,0,0,80); banner.Position=UDim2.new(0,0,0.5,-40)
    banner.BackgroundColor3=Color3.fromRGB(255,255,255); banner.BackgroundTransparency=0.1
    banner.BorderSizePixel=0; banner.ZIndex=5; banner.Parent=announceGui

    local txt = Instance.new("TextLabel")
    txt.Size=UDim2.fromScale(1,1); txt.BackgroundTransparency=1
    txt.Font=Enum.Font.GothamBlack; txt.TextSize=28; txt.ZIndex=6
    txt.Text=rollerName .. " rolled SECRET: " .. tostring(itemName) .. "!"
    txt.TextColor3=Color3.fromRGB(255,220,0); txt.Parent=banner

    -- Fireworks: spawn colored squares
    task.spawn(function()
        for i=1,30 do
            task.wait(0.33)
            local spark = Instance.new("Frame")
            spark.Size=UDim2.new(0,12,0,12)
            spark.Position=UDim2.new(math.random(10,90)/100,0,math.random(10,90)/100,0)
            spark.BackgroundColor3=Color3.fromHSV(math.random()/1,0.9,1)
            spark.BackgroundTransparency=0; spark.BorderSizePixel=0; spark.ZIndex=7; spark.Parent=announceGui
            Instance.new("UICorner",spark).CornerRadius=UDim.new(1,0)
            tw(spark,TweenInfo.new(1,Enum.EasingStyle.Quad),{BackgroundTransparency=1,Size=UDim2.new(0,30,0,30)})
            task.delay(1.1,function() spark:Destroy() end)
        end
    end)

    -- Pulse banner
    tw(banner,TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,10,true),{BackgroundTransparency=0.4})

    -- Remove after 10 seconds
    task.delay(10, function() announceGui:Destroy() end)
end)

print("[SpinAnimation] Loaded (brainrot + item spin + SECRET announce)")
