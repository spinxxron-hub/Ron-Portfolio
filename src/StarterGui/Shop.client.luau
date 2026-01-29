local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local remotes = Services.GetService.rs.Remotes

local players = Services.GetService.p
local player = players.LocalPlayer

local playerGui = player.PlayerGui
local shopGui = playerGui:WaitForChild("ShopGui")

local shopBackground = shopGui.Background
local container = shopBackground.Container
local contents = container.Contents

local exitButton = contents:FindFirstChild("Exit")

local function ToggleOpen()
	local isOpen = shopBackground.Visible

	if isOpen then
		shopBackground.Visible = false
	else
		shopBackground.Visible = true
	end
end

remotes.ToggleShop.Event:Connect(ToggleOpen)
exitButton.Activated:Connect(ToggleOpen)
