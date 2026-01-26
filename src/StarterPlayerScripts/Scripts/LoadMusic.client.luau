local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local shared = Services.GetService.rs.Shared

local musicModules = shared.MusicPlayer
local musicMain = musicModules:WaitForChild("MusicMain", 10) -- waits max 10 seconds

if musicMain then
	require(musicMain).Init()
end
