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
    -- New structured effects
    if effectName == "shake" then
        doShake(data.intensity, data.duration)
    elseif effectName == "tint" then
        doTint(data.r, data.g, data.b, data.saturation, data.duration)
    elseif effectName == "flash" then
        doFlash(data.r, data.g, data.b)
    elseif effectName == "fog" then
        doFog(data.near, data.far, data.r, data.g, data.b, data.duration)

    -- Legacy disaster-name events (backward compatibility)
    elseif effectName == "Flood" then
        clearAllEffects()
        doTint(100, 140, 255, 0.2, 25)
    elseif effectName == "Sandstorm" then
        clearAllEffects()
        doTint(255, 200, 100, 0.3, 25)
    elseif effectName == "Blizzard" then
        clearAllEffects()
        doTint(200, 220, 255, 0.5, 25)
    elseif effectName == "Lightning Storm" then
        clearAllEffects()
        for i = 0, 4 do
            task.delay(i * 1.8, function()
                doFlash(200, 220, 255)
            end)
        end
    elseif effectName == "Earthquake" then
        clearAllEffects()
        doShake(0.8, 20)
    end
end)
