-- MapPrototype.server.lua
-- Generates a one-shot test map at the game island origin (500, 0, 0).
-- To remove: delete this file from src/server/ — nothing else references it.

local DEBUG_MODE = false
local function dprint(...) if DEBUG_MODE then print(...) end end

math.randomseed(os.clock())

local ORIGIN = Vector3.new(500, 0, 0)
local RADIUS = 42

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
local STRUCT_NAMES = { "Pillar", "Wall", "Block", "Slab", "Spire" }

local folder = Instance.new("Folder")
folder.Name   = "TestMap"
folder.Parent = workspace

local count = 0

local function rmat()   return MATERIALS[math.random(#MATERIALS)] end
local function rcol()   return COLORS[math.random(#COLORS)] end
local function rname(t) return t[math.random(#t)] end

local function spawnPart(name, size, cf)
	local p = Instance.new("Part")
	p.Name       = name
	p.Size       = size
	p.CFrame     = cf
	p.Material   = rmat()
	p.Color      = rcol()
	p.Anchored   = true
	p.CanCollide = true
	p.Parent     = folder
	count       += 1
end

local function diskPoint(cx, cz, r)
	local a = math.random() * math.pi * 2
	local d = math.sqrt(math.random()) * r
	return cx + math.cos(a) * d, cz + math.sin(a) * d
end

local function randY() return math.random() * math.pi * 2 end

-- ── 1. Terrain layer: flat rock slabs spread across the play area (~150 parts) ──
for _ = 1, 150 do
	local x, z = diskPoint(ORIGIN.X, ORIGIN.Z, RADIUS)
	local sx = 1.2 + math.random() * 2.8
	local sy = 0.3 + math.random() * 0.5
	local sz = 1.2 + math.random() * 2.8
	local pos = Vector3.new(x, ORIGIN.Y + sy * 0.5, z)
	spawnPart(rname(ROCK_NAMES), Vector3.new(sx, sy, sz),
		CFrame.new(pos) * CFrame.Angles(0, randY(), 0))
end

-- ── 2. Surface scatter: small rocks sitting on the terrain (~150 parts) ──
for _ = 1, 150 do
	local x, z = diskPoint(ORIGIN.X, ORIGIN.Z, RADIUS)
	local sx = 0.6 + math.random() * 1.8
	local sy = 0.5 + math.random() * 1.0
	local sz = 0.6 + math.random() * 1.8
	local oy = math.random() * 0.6
	local pos = Vector3.new(x, ORIGIN.Y + sy * 0.5 + oy, z)
	local tiltX = (math.random() - 0.5) * 0.5
	local tiltZ = (math.random() - 0.5) * 0.5
	spawnPart(rname(ROCK_NAMES), Vector3.new(sx, sy, sz),
		CFrame.new(pos) * CFrame.Angles(tiltX, randY(), tiltZ))
end

-- ── 3. Ruined structures: 10 clusters placed in a loose ring (~200 parts) ──
for s = 1, 10 do
	local angle = (s / 10) * math.pi * 2 + (math.random() - 0.5) * 0.6
	local dist  = 14 + math.random() * 20
	local cx    = ORIGIN.X + math.cos(angle) * dist
	local cz    = ORIGIN.Z + math.sin(angle) * dist
	local cy    = ORIGIN.Y

	-- Scattered base debris around the cluster centre (8–12 parts)
	for _ = 1, math.random(8, 12) do
		local ox = (math.random() - 0.5) * 10
		local oz = (math.random() - 0.5) * 10
		local sx = 0.8 + math.random() * 2.0
		local sy = 0.5 + math.random() * 1.2
		local sz = 0.8 + math.random() * 2.0
		spawnPart("Rubble", Vector3.new(sx, sy, sz),
			CFrame.new(cx + ox, cy + sy * 0.5, cz + oz) * CFrame.Angles(0, randY(), 0))
	end

	-- Stacked pillar / ruined wall rising from the cluster (5–8 parts)
	local px  = cx + (math.random() - 0.5) * 4
	local pz  = cz + (math.random() - 0.5) * 4
	local topY = cy
	for _ = 1, math.random(5, 8) do
		local sx = 0.8 + math.random() * 1.8
		local sy = 0.7 + math.random() * 0.9
		local sz = 0.8 + math.random() * 1.8
		local jx = (math.random() - 0.5) * 0.4
		local jz = (math.random() - 0.5) * 0.4
		spawnPart(rname(STRUCT_NAMES), Vector3.new(sx, sy, sz),
			CFrame.new(px + jx, topY + sy * 0.5, pz + jz) * CFrame.Angles(0, randY(), 0))
		topY += sy
	end

	-- Outer rubble strewn beyond the cluster (3–5 parts)
	for _ = 1, math.random(3, 5) do
		local ox = (math.random() - 0.5) * 16
		local oz = (math.random() - 0.5) * 16
		local sx = 0.5 + math.random() * 1.4
		local sy = 0.4 + math.random() * 0.7
		local sz = 0.5 + math.random() * 1.4
		spawnPart("Chunk", Vector3.new(sx, sy, sz),
			CFrame.new(cx + ox, cy + sy * 0.5, cz + oz) * CFrame.Angles(0, randY(), 0))
	end

	dprint("[MapPrototype] structure", s, "at", math.floor(cx), math.floor(cz))
end

print(string.format("[MapPrototype] generated %d parts", count))
