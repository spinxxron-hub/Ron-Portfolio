local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local profileStore = require(Services.GetService.sss.ServerPackages.ProfileStore)

local remotes = Services.GetService.rs.Remotes

local profileTemplate = {
	Favorites = {}, -- start empty
}

local playerStore = profileStore.New("MusicFavorites", profileTemplate)
local profiles = {}

-- RemoteEvent
local loadFavoriteEvent = remotes.LoadFavorite
local addFavoriteEvent = remotes.AddFavorite

-- Load favorites for client
loadFavoriteEvent.OnServerEvent:Connect(function(player)
	-- Start session
	local success, profile = pcall(function()
		return playerStore:StartSessionAsync(tostring(player.UserId), {
			Cancel = function()
				return not player.Parent
			end,
		})
	end)

	if success and profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profiles[player.UserId] = profile

		profile.OnSessionEnd:Connect(function()
			profiles[player.UserId] = nil
			if player.Parent then
				player:Kick("Profile session ended. Please rejoin.")
			end
		end)

		local favorites = profile.Data.Favorites

		loadFavoriteEvent:FireClient(player, favorites)
	else
		player:Kick("Failed to load profile. Please rejoin.")
	end
end)

-- Toggle favorite for a song
addFavoriteEvent.OnServerEvent:Connect(function(player, songData)
	local profile = profiles[player.UserId]
	if not profile then
		return warn("No profile loaded for", player.Name)
	end

	-- songData expected: { Name = "SongName", Id = "123456" }
	local name = songData.Name
	local id = songData.Id

	if not name or not id then
		return warn("Invalid songData")
	end

	local favorites = profile.Data.Favorites

	if favorites[name] then
		-- Already favorite, remove it
		favorites[name] = nil
		print(player.Name, "removed favorite:", name)
	else
		-- Add to favorites
		favorites[name] = { ["Id"] = "rbxassetid://" .. tostring(id) }
		print(player.Name, "added favorite:", name)
	end

	-- Save the profile asynchronously
	profile:Save()
end)

-- Save on leave
Services.GetService.p.PlayerRemoving:Connect(function(player)
	local profile = profiles[player.UserId]
	if profile ~= nil then
		profile:EndSession()
	end
end)
