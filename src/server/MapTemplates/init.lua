local MapTemplates = {}

local Island_Ruins = require(script.Island_Ruins)

local registry = {
	Island_Ruins,
}

function MapTemplates.getRandom(rng: Random)
	return registry[rng:NextInteger(1, #registry)]
end

function MapTemplates.getAll()
	return registry
end

return MapTemplates
