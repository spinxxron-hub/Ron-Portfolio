local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local shared = Services.GetService.rs.Shared

local musicModules = shared.MusicPlayer
local musicMain = musicModules:WaitForChild("MusicMain")

if musicMain then
	require(musicModules.MusicMain).Init()
end
