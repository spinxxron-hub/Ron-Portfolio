local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local packages = Services.GetService.rs.Packages
local remotes = Services.GetService.rs.Remotes

local TopbarPlus = require(packages:WaitForChild("TopbarPlus"))
local dropdownIcon

-- Create the icon

local settingsIcon = TopbarPlus
	.new()
	--:bindEvent("selected", function()
	--	remotes.ToggleMusicPlayer:Fire()
	--end)
	:setName("SettingsIcon")
	:setImage("rbxassetid://4492476121")
	:setCaption("Settings")
	:oneClick()
	:setDisplayOrder(5)

local menuIcon = TopbarPlus.new()
	:notify()
	:setName("MenuA")
	:setLabel("Menu")
	:setCaption("Example Menu")
	:bindToggleKey(Enum.KeyCode.M)
	:setMenu({
		TopbarPlus.new()
			:setName("Dropdown")
			:setImage(97985615720721)
			:call(function(icon)
				dropdownIcon = icon
			end)
			:oneClick(false)
			:setImageScale(1.04)
			:setCaption("View Items")
			:setDropdown({
				TopbarPlus
					.new()
					:setName("Item A") -- Captures
					:setOrder(5)
					:call(function(icon)
						print("A")
					end),
			}),
		TopbarPlus.new()
			:bindEvent("selected", function()
				print("shop")
			end)
			:setImage(4882429582)
			:setCaption("Shop"),
		--:bindToggleItem(gui.Shop)
		--:call(function(icon)
		--gui.Shop.CloseButton.MouseButton1Click:Connect(function()
		--	icon:deselect()
		--end)
		--	while true do
		--		task.wait(3)
		--icon:notify()
		--	end
		--end),
	})

local musicIcon = TopbarPlus.new()
	:bindEvent("selected", function()
		remotes.ToggleMusicPlayer:Fire()
	end)
	:setName("MusicIcon")
	:setLabel("Music")
	:setImage("rbxassetid://7059338404")
	:setCaption("Start listening to Music")
	:oneClick()
	:setDisplayOrder(5)
