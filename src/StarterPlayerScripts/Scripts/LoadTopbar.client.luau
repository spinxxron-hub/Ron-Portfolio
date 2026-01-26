local Services = require(game:GetService("ReplicatedStorage").Shared.Services)

local packages = Services.GetService.rs.Packages
local remotes = Services.GetService.rs.Remotes

local Icon = require(packages:WaitForChild("TopbarPlus"))

Icon.new()
	:bindEvent("selected", function()
		remotes.ToggleMusicPlayer:Fire()
	end)
	:setName("MusicIcon")
	:setLabel("Music")
	:setImage("rbxassetid://7059338404")
	:setCaption("Start listening to Music")
	:oneClick()
	:setDisplayOrder(5)
