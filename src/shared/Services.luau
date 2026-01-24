local function getService(serviceName)
	return game:GetService(serviceName) or nil
end

local Services = {}

Services.GetService = {
	["rs"] = getService("ReplicatedStorage"),
	["rf"] = getService("ReplicatedFirst"),
	["ts"] = getService("TweenService"),
	["tps"] = getService("TeleportService"),
	["ps"] = getService("PhysicsService"),
	["ss"] = getService("ServerStorage"),
	["sss"] = getService("ServerScriptService"),
	["l"] = getService("Lighting"),
	["ms"] = getService("MaterialService"),
	["mps"] = getService("MarketplaceService"),
	["d"] = getService("Debris"),
	["dss"] = getService("DataStoreService"),
	["p"] = getService("Players"),
	["uis"] = getService("UserInputService"),
	["gs"] = getService("GuiService"),
	["RS"] = getService("RunService"),
	["SS"] = getService("SoundService"),
	["cs"] = getService("CollectionService"),
	["cp"] = getService("ContentProvider"),
	["sg"] = getService("StarterGui"),
	["pps"] = getService("ProximityPromptService"),
}

Services.BaseProperties = {
	["Camera"] = {
		FieldOfView = 70,
		DepthOfField = 0.5,
	},
	["Humanoid"] = {
		WalkSpeed = 16,
		JumpHeight = 5,
	},

	["RespawnTime"] = 3,
}

local random = Random.new()

function Services.Random(val1: number, val2: number)
	return random:NextNumber(val1, val2)
end

function Services.UDim2()
	return UDim2
end

local lerpFunctions = {
	["number"] = function(a, b, c, dt)
		return a + (b - a) * (1 - c ^ dt)
	end,
}

function Services.LerpWithTime(a, b, c, dt) --start, goal, fraction, delta
	return lerpFunctions[typeof(a)](a, b, c, dt)
end

return Services
