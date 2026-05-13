-- DisasterEffects LocalScript
-- Handles all client-side visual effects for Disaster RNG
-- Supports both new structured effect events and legacy disaster-name events

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local DisasterEvent = ReplicatedStorage:WaitForChild("DisasterEvent")

-- Active effect cleanup callbacks
local activeEffects = {}

local function clearEffect(name)
    if activeEffects[name] then
        activeEffects[name]()
        activeEffects[name] = nil
    end
end

local function clearAllEffects()
    for name in pairs(activeEffects) do
        clearEffect(name)
    end
end

-- SHAKE: additive camera shake via RenderStepped
-- Multiple simultaneous shakes stack together
local activeShakes = {}
local shakeConn = RunService.RenderStepped:Connect(function(dt)
    local totalX, totalY = 0, 0
    for i = #activeShakes, 1, -1 do
        local s = activeShakes[i]
        s.elapsed = s.elapsed + dt
        if s.elapsed >= s.duration then
            table.remove(activeShakes, i)
        else
            local t = 1 - (s.elapsed / s.duration)
            local mag = t * s.intensity
            totalX = totalX + (math.random() - 0.5) * 2 * mag
            totalY = totalY + (math.random() - 0.5) * 2 * mag
        end
    end
    if #activeShakes > 0 then
        camera.CFrame = camera.CFrame * CFrame.new(totalX, totalY, 0)
    end
end)

local function doShake(intensity, duration)
    table.insert(activeShakes, {intensity = intensity, duration = duration, elapsed = 0})
end

-- TINT: ColorCorrectionEffect on Lighting
local function doTint(r, g, b, saturation, duration)
    clearEffect("tint")
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "DisasterTint"
    cc.TintColor = Color3.fromRGB(r, g, b)
    cc.Saturation = -(saturation or 0)
    cc.Parent = Lighting
    activeEffects["tint"] = function()
        if cc and cc.Parent then cc:Destroy() end
    end
    task.delay(duration or 20, function()
        clearEffect("tint")
    end)
end

-- FLASH: bright ColorCorrection that decays quickly
local function doFlash(r, g, b)
    local cc = Instance.new("ColorCorrectionEffect")
    cc.Name = "DisasterFlash"
    cc.TintColor = Color3.fromRGB(r, g, b)
    cc.Brightness = 0.8
    cc.Parent = Lighting
    TweenService:Create(cc, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 0,
        TintColor = Color3.new(1, 1, 1)
    }):Play()
    task.delay(0.5, function()
        if cc and cc.Parent then cc:Destroy() end
    end)
end

-- FOG: tween Lighting fog properties, restores originals when cleared
local function doFog(near, far, r, g, b, duration)
    clearEffect("fog")
    local origFogStart = Lighting.FogStart
    local origFogEnd = Lighting.FogEnd
    local origFogColor = Lighting.FogColor
    TweenService:Create(Lighting, TweenInfo.new(1, Enum.EasingStyle.Quad), {
        FogStart = near,
        FogEnd = far,
        FogColor = Color3.fromRGB(r, g, b)
    }):Play()
    activeEffects["fog"] = function()
        TweenService:Create(Lighting, TweenInfo.new(2, Enum.EasingStyle.Quad), {
            FogStart = origFogStart,
            FogEnd = origFogEnd,
            FogColor = origFogColor
        }):Play()
    end
    task.delay(duration or 20, function()
        clearEffect("fog")
    end)
end

-- Handle server events
DisasterEvent.OnClientEvent:Connect(function(effectName, data)
    -- Structured effects
    if effectName == "shake" then
        doShake(data.intensity, data.duration)
    elseif effectName == "tint" then
        doTint(data.r, data.g, data.b, data.saturation, data.duration)
    elseif effectName == "flash" then
        doFlash(data.r, data.g, data.b)
    elseif effectName == "fog" then
        doFog(data.near, data.far, data.r, data.g, data.b, data.duration)
    elseif effectName == "clearEffects" then
        clearAllEffects()

    -- Meteor incoming: subtle shake on warning
    elseif effectName == "meteorWarning" then
        doShake(0.08, 0.4)
    -- Lightning pre-flash
    elseif effectName == "lightningWarning" then
        doFlash(240, 240, 180)
    -- Tsunami siren: tint + shake
    elseif effectName == "tsunamiWarning" then
        clearAllEffects()
        doShake(0.3, 5)
        doTint(0, 80, 200, 0.1, 12)

    -- Legacy disaster-name events
    elseif effectName == "Flood" then
        clearAllEffects()
        doTint(100, 140, 255, 0.2, 65)
    elseif effectName == "Sandstorm" then
        clearAllEffects()
        doTint(255, 200, 100, 0.3, 45)
        doFog(0, 150, 200, 170, 100, 45)
    elseif effectName == "Blizzard" then
        clearAllEffects()
        doTint(200, 220, 255, 0.5, 55)
        doFog(0, 280, 200, 215, 255, 55)
    elseif effectName == "Lightning Storm" then
        clearAllEffects()
        for i = 0, 14 do
            task.delay(i * 1.2, function()
                doFlash(220, 230, 255)
            end)
        end
    elseif effectName == "Earthquake" then
        clearAllEffects()
        doShake(0.8, 30)
    elseif effectName == "Tsunami" then
        clearAllEffects()
        doShake(0.5, 7)
        doTint(0, 60, 180, 0.15, 12)
    elseif effectName == "Acid Rain" then
        clearAllEffects()
        doTint(80, 200, 60, 0.2, 65)
    elseif effectName == "Volcanic Eruption" then
        clearAllEffects()
        doTint(255, 80, 30, 0.3, 40)
        doShake(0.15, 40)
    elseif effectName == "Tornado" then
        clearAllEffects()
        doShake(0.1, 25)
        doTint(160, 160, 200, 0.1, 25)
    elseif effectName == "Meteor Strike" then
        clearAllEffects()
        doShake(0.05, 30)
    end
end)
