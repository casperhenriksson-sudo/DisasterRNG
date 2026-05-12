-- SoundController LocalScript
-- Manages all game audio: lobby music, tension music, SFX

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RoundEvent = ReplicatedStorage:WaitForChild("RoundEvent")
local player = Players.LocalPlayer

-- Create sounds in SoundService
local function makeSound(name, id, volume, looped)
	local existing = SoundService:FindFirstChild(name)
	if existing then return existing end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Looped = looped or false
	s.RollOffMaxDistance = 0
	s.Parent = SoundService
	return s
end

local lobbyMusic   = makeSound("LobbyMusic",   "rbxassetid://1843362464", 0.4, true)
local tensionMusic = makeSound("TensionMusic",  "rbxassetid://1843199128", 0.0, true)
local beepSFX      = makeSound("CountdownBeep","rbxassetid://9119648704", 0.6, false)
local fanfareSFX   = makeSound("RoundFanfare",  "rbxassetid://9120386436", 0.7, false)
local roundEndSFX  = makeSound("RoundEnd",      "rbxassetid://9114454247", 0.6, false)
local deathSFX     = makeSound("DeathSound",    "rbxassetid://3506776052", 0.8, false)

local function fadeVolume(sound, target, duration)
	TweenService:Create(sound,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{Volume = target}
	):Play()
end

-- Start lobby music immediately
lobbyMusic:Play()

-- Track if local player died this round
local diedThisRound = false

RoundEvent.OnClientEvent:Connect(function(event, data)
	if event == "LobbyCountdown" then
		local t = tonumber(data) or 0
		if t <= 3 and t > 0 then beepSFX:Play() end

	elseif event == "RoundStart" then
		diedThisRound = false
		fanfareSFX:Play()
		fadeVolume(lobbyMusic, 0, 2)
		tensionMusic.Volume = 0
		tensionMusic:Play()
		fadeVolume(tensionMusic, 0.5, 3)

	elseif event == "RoundEnd" then
		roundEndSFX:Play()
		fadeVolume(tensionMusic, 0, 1.5)
		task.delay(1.5, function() tensionMusic:Stop() end)
		task.delay(2, function() fadeVolume(lobbyMusic, 0.4, 2) end)

	elseif event == "PlayerDied" then
		local name = (type(data) == "table" and data.name) or ""
		if name == player.Name then
			deathSFX:Play()
			diedThisRound = true
		end

	elseif event == "LobbyWaiting" then
		-- Ensure lobby music is on
		if not lobbyMusic.IsPlaying then
			lobbyMusic:Play()
			fadeVolume(lobbyMusic, 0.4, 1)
		end
	end
end)

-- Death sound via character Humanoid directly (backup in case PlayerDied fires late)
local function connectDeath(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		hum.Died:Connect(function()
			if not diedThisRound then
				diedThisRound = true
				deathSFX:Play()
			end
		end)
	end
end
player.CharacterAdded:Connect(connectDeath)
if player.Character then connectDeath(player.Character) end
