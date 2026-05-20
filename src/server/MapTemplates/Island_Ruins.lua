local CollectionService = game:GetService("CollectionService")

-- Tune these to hit part-count targets without touching generation logic.
local TERRAIN_PARTS  = 1000
local LOOSE_STONES   = 250
local TOWER_COUNT    = 10   -- ~35-45 parts each
local WALL_COUNT     = 12   -- ~35-50 parts each
local HEAP_COUNT     = 8    -- ~12-22 parts each
-- Expected total: ~2400-2700 destructible parts + 12 SpawnLocations

local MATERIALS = {
	Enum.Material.Slate,
	Enum.Material.Cobblestone,
	Enum.Material.Rock,
	Enum.Material.Granite,
	Enum.Material.Concrete,
}

local COLORS = {
	Color3.fromRGB(130, 130, 130),
	Color3.fromRGB(85,  85,  85),
	Color3.fromRGB(155, 145, 135),
	Color3.fromRGB(105, 110, 115),
	Color3.fromRGB(172, 168, 158),
}

local ROCK_NAMES   = { "Rock", "Rubble", "Chunk", "Stone" }
local STRUCT_NAMES = { "Pillar", "Wall", "Block", "Slab" }

local function pick(rng: Random, t: {any})
	return t[rng:NextInteger(1, #t)]
end

local function makePart(rng: Random, name: string, size: Vector3, cf: CFrame): Part
	local p      = Instance.new("Part")
	p.Name       = name
	p.Size       = size
	p.CFrame     = cf
	p.Material   = pick(rng, MATERIALS)
	p.Color      = pick(rng, COLORS)
	p.Anchored   = true
	p.CanCollide = true
	CollectionService:AddTag(p, "Destructible")
	return p
end

-- Island shape: union of N overlapping ellipses around origin.
local function buildDisks(rng: Random, origin: Vector3, count: number, radius: number)
	local disks = {}
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(0, radius * 0.35)
		disks[#disks + 1] = {
			cx = origin.X + math.cos(a) * d,
			cz = origin.Z + math.sin(a) * d,
			rx = rng:NextNumber(radius * 0.55, radius),
			rz = rng:NextNumber(radius * 0.55, radius),
		}
	end
	return disks
end

local function inIsland(disks, x: number, z: number): boolean
	for _, d in ipairs(disks) do
		local dx = (x - d.cx) / d.rx
		local dz = (z - d.cz) / d.rz
		if dx * dx + dz * dz <= 1 then return true end
	end
	return false
end

-- Rejection-sampled random point within the island.
local function islandPoint(rng: Random, disks, origin: Vector3, radius: number): (number, number)
	for _ = 1, 60 do
		local x = origin.X + rng:NextNumber(-radius, radius)
		local z = origin.Z + rng:NextNumber(-radius, radius)
		if inIsland(disks, x, z) then return x, z end
	end
	return origin.X, origin.Z  -- fallback to centre
end

-- Ruined tower: central stack + base debris + fallen blocks (~35-45 parts)
local function buildTower(rng: Random, cx: number, cy: number, cz: number, out: {Instance})
	-- Base debris ring
	for _ = 1, rng:NextInteger(10, 16) do
		local ox = rng:NextNumber(-7, 7)
		local oz = rng:NextNumber(-7, 7)
		local sx = rng:NextNumber(0.8, 2.5)
		local sy = rng:NextNumber(0.5, 1.5)
		local sz = rng:NextNumber(0.8, 2.5)
		local cf = CFrame.new(cx + ox, cy + sy * 0.5, cz + oz)
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3))
		out[#out + 1] = makePart(rng, "Rubble", Vector3.new(sx, sy, sz), cf)
	end
	-- Column stack
	local px, pz = cx + rng:NextNumber(-1.5, 1.5), cz + rng:NextNumber(-1.5, 1.5)
	local topY = cy
	for _ = 1, rng:NextInteger(8, 14) do
		local sx = rng:NextNumber(1.2, 2.8)
		local sy = rng:NextNumber(0.8, 1.4)
		local sz = rng:NextNumber(1.2, 2.8)
		local cf = CFrame.new(px + rng:NextNumber(-0.3, 0.3), topY + sy * 0.5, pz + rng:NextNumber(-0.3, 0.3))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		out[#out + 1] = makePart(rng, pick(rng, STRUCT_NAMES), Vector3.new(sx, sy, sz), cf)
		topY += sy
	end
	-- Fallen blocks
	for _ = 1, rng:NextInteger(5, 9) do
		local ox = rng:NextNumber(-11, 11)
		local oz = rng:NextNumber(-11, 11)
		local sx = rng:NextNumber(1.0, 3.0)
		local sy = rng:NextNumber(0.8, 2.0)
		local sz = rng:NextNumber(1.0, 3.0)
		local tilt = rng:NextNumber(0.5, 1.2) * (rng:NextNumber(0, 1) > 0.5 and 1 or -1)
		local cf = CFrame.new(cx + ox, cy + sy * 0.5, cz + oz)
			* CFrame.Angles(tilt, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.4, 0.4))
		out[#out + 1] = makePart(rng, pick(rng, STRUCT_NAMES), Vector3.new(sx, sy, sz), cf)
	end
end

-- Crumbled wall: linear row of stacked blocks, tapered at edges (~35-50 parts)
local function buildWall(rng: Random, cx: number, cy: number, cz: number, out: {Instance})
	local length    = rng:NextInteger(6, 12)
	local maxHeight = rng:NextInteger(3, 7)
	local angle     = rng:NextNumber(0, math.pi * 2)
	local bw        = rng:NextNumber(1.2, 2.4)

	for col = 0, length - 1 do
		local colHeight = math.max(1, math.floor(
			maxHeight - math.abs(col - length * 0.5) * 0.5 + rng:NextNumber(-1, 1) + 0.5))
		local wx = cx + math.cos(angle) * col * bw
		local wz = cz + math.sin(angle) * col * bw
		local topY = cy
		for _ = 1, colHeight do
			local sx = bw + rng:NextNumber(-0.2, 0.2)
			local sy = rng:NextNumber(0.8, 1.4)
			local sz = rng:NextNumber(1.2, 2.4)
			local cf = CFrame.new(wx + rng:NextNumber(-0.15, 0.15), topY + sy * 0.5, wz + rng:NextNumber(-0.15, 0.15))
				* CFrame.Angles(0, angle + rng:NextNumber(-0.1, 0.1), 0)
			out[#out + 1] = makePart(rng, pick(rng, STRUCT_NAMES), Vector3.new(sx, sy, sz), cf)
			topY += sy
		end
	end
	-- Surrounding scatter
	for _ = 1, rng:NextInteger(4, 9) do
		local ox = rng:NextNumber(-9, 9)
		local oz = rng:NextNumber(-9, 9)
		local sx = rng:NextNumber(0.6, 2.0)
		local sy = rng:NextNumber(0.4, 1.2)
		local sz = rng:NextNumber(0.6, 2.0)
		local cf = CFrame.new(cx + ox, cy + sy * 0.5, cz + oz)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		out[#out + 1] = makePart(rng, "Rubble", Vector3.new(sx, sy, sz), cf)
	end
end

-- Rubble heap: chaotic layered pile (~12-22 parts)
local function buildHeap(rng: Random, cx: number, cy: number, cz: number, out: {Instance})
	local count = rng:NextInteger(12, 22)
	for i = 1, count do
		local layer  = math.floor((i - 1) / 5)
		local spread = math.max(0.4, 4.5 - layer * 1.5)
		local sx     = rng:NextNumber(0.5, 2.2)
		local sy     = rng:NextNumber(0.5, 1.8)
		local sz     = rng:NextNumber(0.5, 2.2)
		local cf     = CFrame.new(cx + rng:NextNumber(-spread, spread),
		                          cy + layer * 1.0 + sy * 0.5,
		                          cz + rng:NextNumber(-spread, spread))
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.6, 0.6))
		out[#out + 1] = makePart(rng, "Rubble", Vector3.new(sx, sy, sz), cf)
	end
end

-- ─────────────────────────────────────────────────────────────

local Island_Ruins = {}
Island_Ruins.name  = "Island_Ruins"
Island_Ruins.biome = "ruins"

function Island_Ruins.build(rng: Random, origin: Vector3, config): {Instance}
	local radius = config.MAP_SIZE * 0.38   -- ~114 studs at MAP_SIZE 300
	local out    = {}

	local disks = buildDisks(rng, origin, 6, radius)

	-- 1. Terrain: flat slabs covering the island surface
	local placed = 0
	local safety = TERRAIN_PARTS * 3
	while placed < TERRAIN_PARTS and safety > 0 do
		safety -= 1
		local x, z = islandPoint(rng, disks, origin, radius)
		local sx = rng:NextNumber(1.2, 4.0)
		local sy = rng:NextNumber(0.3, 1.0)
		local sz = rng:NextNumber(1.2, 4.0)
		local cf = CFrame.new(x, origin.Y + sy * 0.5 + rng:NextNumber(-0.4, 0.4), z)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		out[#out + 1] = makePart(rng, pick(rng, ROCK_NAMES), Vector3.new(sx, sy, sz), cf)
		placed += 1
	end

	-- 2. Structures (placed within 85% of island radius to keep them on land)
	local innerRadius = radius * 0.85
	for _ = 1, TOWER_COUNT do
		local x, z = islandPoint(rng, disks, origin, innerRadius)
		buildTower(rng, x, origin.Y, z, out)
	end
	for _ = 1, WALL_COUNT do
		local x, z = islandPoint(rng, disks, origin, innerRadius)
		buildWall(rng, x, origin.Y, z, out)
	end
	for _ = 1, HEAP_COUNT do
		local x, z = islandPoint(rng, disks, origin, innerRadius)
		buildHeap(rng, x, origin.Y, z, out)
	end

	-- 3. Loose stones scattered across the island
	for _ = 1, LOOSE_STONES do
		local x, z = islandPoint(rng, disks, origin, radius)
		local sx   = rng:NextNumber(0.5, 1.8)
		local sy   = rng:NextNumber(0.4, 1.2)
		local sz   = rng:NextNumber(0.5, 1.8)
		local cf   = CFrame.new(x, origin.Y + sy * 0.5 + rng:NextNumber(0, 0.5), z)
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5))
		out[#out + 1] = makePart(rng, "Rock", Vector3.new(sx, sy, sz), cf)
	end

	-- 4. SpawnLocations: evenly spaced ring, randomised radius
	for i = 1, 12 do
		local a    = (i / 12) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local dist = radius * rng:NextNumber(0.3, 0.65)
		local sp   = Instance.new("SpawnLocation")
		sp.Name      = "Spawn_" .. i
		sp.Size      = Vector3.new(4, 1, 4)
		sp.CFrame    = CFrame.new(origin.X + math.cos(a) * dist, origin.Y + 0.5, origin.Z + math.sin(a) * dist)
		sp.Anchored  = true
		sp.Material  = Enum.Material.SmoothPlastic
		sp.BrickColor = BrickColor.new("Medium stone grey")
		sp.TeamColor  = BrickColor.new("Medium stone grey")
		sp.Neutral   = true
		sp.Duration  = 0
		out[#out + 1] = sp
	end

	return out
end

return Island_Ruins
