local MapConfig   = require(game.ReplicatedStorage.MapConfig)
local MapTemplates = require(script.Parent.MapTemplates)

local MapManager = {}

local currentMap: Model? = nil

function MapManager.init()
	-- nothing to initialise until destruction hooks are wired
end

function MapManager.buildMap(seed: number?): Model
	MapManager.cleanupMap()

	local rng      = Random.new(seed or tick())
	local template = MapTemplates.getRandom(rng)

	local map      = Instance.new("Model")
	map.Name       = "CurrentMap"

	-- Invisible anchor at origin — required PrimaryPart
	local anchor        = Instance.new("Part")
	anchor.Name         = "Anchor"
	anchor.Size         = Vector3.new(1, 1, 1)
	anchor.CFrame       = CFrame.new(MapConfig.MAP_ORIGIN)
	anchor.Anchored     = true
	anchor.CanCollide   = false
	anchor.Transparency = 1
	anchor.Parent       = map
	map.PrimaryPart     = anchor

	-- Build template and parent all instances under map
	local instances = template.build(rng, MapConfig.MAP_ORIGIN, MapConfig)
	local count = 0
	for _, inst in ipairs(instances) do
		inst.Parent = map
		count += 1
	end

	map.Parent  = workspace
	currentMap  = map

	print(string.format("[MapManager] built %q — %d instances (seed %s)",
		template.name, count, tostring(seed)))

	return map
end

function MapManager.cleanupMap()
	if currentMap then
		currentMap:Destroy()
		currentMap = nil
	end
	local orphan = workspace:FindFirstChild("CurrentMap")
	if orphan then orphan:Destroy() end
end

function MapManager.getCurrentMap(): Model?
	return currentMap
end

function MapManager.getMapBounds(): {min: Vector3, max: Vector3, center: Vector3}
	local half = MapConfig.MAP_SIZE / 2
	local o    = MapConfig.MAP_ORIGIN
	return {
		min    = o - Vector3.new(half, 0, half),
		max    = o + Vector3.new(half, 0, half),
		center = o,
	}
end

return MapManager
