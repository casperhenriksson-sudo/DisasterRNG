local MapConfig = require(game.ReplicatedStorage.MapConfig)

local MapManager = {}

local currentMap: Model? = nil

function MapManager.init()
	-- placeholder: nothing to initialise until templates exist
end

-- Returns a Model named "CurrentMap" with a PrimaryPart set.
-- seed is accepted but unused until procedural generation is wired.
function MapManager.buildMap(seed: number?): Model
	MapManager.cleanupMap()

	local map = Instance.new("Model")
	map.Name = "CurrentMap"

	local anchor = Instance.new("Part")
	anchor.Name       = "Anchor"
	anchor.Size       = Vector3.new(1, 1, 1)
	anchor.CFrame     = CFrame.new(MapConfig.MAP_ORIGIN)
	anchor.Anchored   = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = map

	map.PrimaryPart = anchor
	map.Parent      = workspace

	currentMap = map
	return map
end

function MapManager.cleanupMap()
	if currentMap then
		currentMap:Destroy()
		currentMap = nil
	end
	-- catch any orphaned CurrentMap left by a previous session
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
