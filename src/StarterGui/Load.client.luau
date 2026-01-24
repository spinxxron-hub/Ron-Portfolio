local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local shared = Services.GetService.rs.Shared
local remotes = Services.GetService.rs.Remotes

local MusicModules = shared.Music
local assets = Services.GetService.rs.Assets

local players = Services.GetService.p
local player = players.LocalPlayer

local mouse = player:GetMouse()

local playerGui = player.PlayerGui

local MusicController = require(MusicModules.MusicController)
local MusicConfigs = require(MusicModules.Configuration)

local musicPlayer = playerGui:WaitForChild("MusicPlayer")
local background = musicPlayer:WaitForChild("Background")
local musicButtonBackground = musicPlayer:WaitForChild("MusicButtonBackground")

local layout = background:WaitForChild("Layout")
local listLayout = background:WaitForChild("ListLayout")

local musicButton = musicButtonBackground.Button
local visualizerBackground = musicButton.Visualizer
local barBackground = musicButton.BarBackground

local visualizerContainer = visualizerBackground.Container
local barContainer = barBackground.Container

local visualizerProgressBar = barContainer.Bar

local listContents = listLayout.Contents
local listContainer = listContents.Container
local listSearchBar = listContents.SearchBar
local listFavoriteBackground = listContents.FavoriteBackground
local listFavorite = listFavoriteBackground.Favorite

local container = layout.Container
local statusFolder = layout:FindFirstChild("Status")

local isPlaying = statusFolder.Playing
local isFavorite = statusFolder.Favorite

local timePlayed = statusFolder.TimePlayed
local timeRemain = statusFolder.TimeRemain

local functionFrames = container.Functions
local musicIcon = container.MusicIcon

local icon = musicIcon:FindFirstChild("Icon")

local buttons = functionFrames:FindFirstChild("Buttons")
local timeBackground = functionFrames:FindFirstChild("TimeBackground")
local namesBackground = functionFrames:FindFirstChild("NamesBackground")

local nextBackground = buttons:FindFirstChild("NextBackground")
local nextButton = nextBackground.Next

local prevBackground = buttons:FindFirstChild("PrevBackground")
local prevButton = prevBackground.Previous

local loopBackground = buttons:FindFirstChild("LoopBackground")
local loopButton = loopBackground.Loop

local shuffleBackground = buttons:FindFirstChild("ShuffleBackground")
local shuffleButton = shuffleBackground.Shuffle

local speedBackground = buttons:FindFirstChild("SpeedBackground")
local speedButton = speedBackground.Speed

local listButtonBackground = buttons:FindFirstChild("ListButtonBackground")
local listButton = listButtonBackground.ListButton

local favoriteBackground = buttons:FindFirstChild("FavoriteBackground")
local favoriteButton = favoriteBackground.Favorite

local speakerBackground = buttons:FindFirstChild("SpeakerBackground")
local speakerMuteButton = speakerBackground.Mute
local speakerUnmuteButton = speakerBackground.Unmute

local toggleBackground = buttons:FindFirstChild("ToggleBackground")
local playButton = toggleBackground.Play
local pauseButton = toggleBackground.Pause

local progressBackground = functionFrames:FindFirstChild("ProgressBackground")
local progressBarBackground = progressBackground.Background
local progressBar = progressBarBackground.Bar

local hovered = false
local holding = false
local moveCon = nil

local initialX, initialY, initialUIPos

local speedEnums = {
	["1"] = 1.0,
	["2"] = 10.5,
	["3"] = 0.75,
}

local speedOrder = { "1", "2", "3" } -- order of speed cycles
local speedIndex = 1 -- start at first speed

local templateConnections = {}

-- songs
local ALL_SONGS = {}

for _, song in ipairs(MusicConfigs.MusicList) do
	table.insert(ALL_SONGS, {
		Id = "rbxassetid://" .. song.SoundId,
		Name = song.MusicName,
		Artist = song.MusicArtist,
		Icon = song.AlbumIcon,
	})
end

table.sort(ALL_SONGS, function(a, b)
	return a.Name:lower() < b.Name:lower()
end)

local SONG_INDEX_BY_ID = {}

for i, song in ipairs(ALL_SONGS) do
	SONG_INDEX_BY_ID[song.Id] = i
end

local function cloneSongs(list)
	local copy = table.clone(list)
	return copy
end

local MusicState = {
	playlist = "Regular",
	pendingPlaylist = nil, -- "Favorites" | "Regular" | nil

	index = 1,

	volume = 1,
	CurrentSpeed = 1,

	paused = true,
	muted = false,
	looped = false,

	repeatMode = "All",

	shuffle = false,
	shuffleOrder = {},
	shuffleIndex = 1,

	TimePlayed = 0,
	TimeRemain = 0,
	songs = cloneSongs(ALL_SONGS),

	favorites = {},

	pausedPosition = 0, -- track position to resume
}

-- Pool for reusing UI templates
local templatePool = {}

local controller = MusicController.new(MusicState)
controller._allSongs = MusicState.songs -- give it ALL_SONGS for regular playlist

local function normalize(str)
	return str:lower():gsub("[%p%c]", ""):gsub("%s+", "")
end

local function RenderFavorite()
	local song = controller.State.songs[controller.State.index]
	if not song then
		return
	end

	if controller:IsFavorite(song) then
		favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 0)
	else
		favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end

remotes.LoadFavorite.OnClientEvent:Connect(function(savedFavorites)
	controller.State.favorites = savedFavorites or {}
	RenderFavorite()
end)

remotes.LoadFavorite:FireServer()

local function ClearTemplate(template)
	if templateConnections[template] then
		templateConnections[template]:Disconnect()
		templateConnections[template] = nil
	end
	if templateConnections[template.Favorite] then
		templateConnections[template.Favorite]:Disconnect()
		templateConnections[template.Favorite] = nil
	end
end

local function GetTemplate()
	for _, t in ipairs(templatePool) do
		if not t.Parent then
			return t
		end
	end
	local template = assets.UI.MusicTemplate:Clone()
	table.insert(templatePool, template)
	return template
end

local function RefreshList(searchText)
	searchText = searchText or ""
	local normalizedSearch = normalize(searchText)

	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("ImageButton") then
			child.Parent = nil -- remove from container for reuse
		end
	end

	local startsWith = {}
	local contains = {}

	local songs = controller.State.songs

	for _, info in ipairs(songs) do
		if normalizedSearch == "" then
			table.insert(contains, info)
		else
			local normalizedName = normalize(info.Name)

			if string.sub(normalizedName, 1, #normalizedSearch) == normalizedSearch then
				table.insert(startsWith, info)
			end
		end
	end

	-- Sort both groups alphabetically
	local function sortByName(a, b)
		return a.Name:lower() < b.Name:lower()
	end

	table.sort(startsWith, sortByName)
	table.sort(contains, sortByName)

	-- Merge lists (startsWith first)
	local filtered = {}

	for _, v in ipairs(startsWith) do
		table.insert(filtered, v)
	end
	for _, v in ipairs(contains) do
		table.insert(filtered, v)
	end

	-- Keep track of duplicate counts for display
	local nameCount = {}
	for _, song in ipairs(filtered) do
		nameCount[song.Name] = (nameCount[song.Name] or 0) + 1
	end

	local displayedCount = {}

	-- Populate UI
	for i, info in ipairs(filtered) do
		local template = GetTemplate()
		ClearTemplate(template)

		template.Parent = listContainer
		template.LayoutOrder = i
		template.Visible = true

		local favorite = controller:CheckFavorite(info)

		if favorite then
			template.Favorite.ImageColor3 = Color3.fromRGB(255, 255, 0)
		else
			template.Favorite.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end

		-- Handle duplicate names in UI
		displayedCount[info.Name] = (displayedCount[info.Name] or 0) + 1
		local displayName = info.Name
		if nameCount[info.Name] > 1 then
			displayName = displayName .. " (" .. displayedCount[info.Name] .. ")"
		end

		template.Name = info.Name
		template.Icon.Image = info.Icon
		template.MusicName.Text = displayName
		template.ArtistName.Text = info.Artist

		local songIndex = table.find(songs, info)

		-- Connect click
		templateConnections[template] = template.Activated:Connect(function()
			controller.State.index = songIndex
			controller.State.pausedPosition = 0
			controller:Play(info)
			isPlaying.Value = true
		end)

		templateConnections[template.Favorite] = template.Favorite.Activated:Connect(function()
			ToggleFavorite(songs[songIndex])
		end)
	end
end

-- Modified Play function to support resume
local function PlayCurrent()
	local song = controller.State.songs[controller.State.index]
	if not song then
		return
	end

	controller:Play(song)

	if controller.Sound then
		controller.Sound.TimePosition = controller.State.pausedPosition or 0
	end

	controller.State.paused = false
	isPlaying.Value = true

	RenderFavorite()
end

-- Modified Pause function to store position
local function PauseCurrent()
	controller.State.pausedPosition = controller.Sound.TimePosition
	controller:Pause()
	controller.State.paused = true
	isPlaying.Value = false
end

local function ChangeLoopMode()
	controller:SetLoop(not controller.State.looped)
	if controller.State.looped then
		loopButton.ImageColor3 = Color3.fromRGB(0, 255, 0) -- active
	else
		loopButton.ImageColor3 = Color3.fromRGB(255, 255, 255) -- inactive
	end
end

local function ChangeShuffleMode()
	controller:SetShuffle(not controller.State.shuffle)
	if controller.State.shuffle then
		shuffleButton.ImageColor3 = Color3.fromRGB(0, 255, 0) -- active
	else
		shuffleButton.ImageColor3 = Color3.fromRGB(255, 255, 255) -- inactive
	end
end

local function ChangeSpeed()
	speedIndex += 1
	if speedIndex > #speedOrder then
		speedIndex = 1
	end

	local speedKey = speedOrder[speedIndex]
	local speedValue = speedEnums[speedKey]

	-- Update controller state

	controller:SetSpeed(speedKey, speedValue)

	-- Update UI
	speedButton.Text = speedValue .. "x"
end

-- Helper for formatting time
local function formatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

loopButton.Activated:Connect(ChangeLoopMode)
shuffleButton.Activated:Connect(ChangeShuffleMode)
speedButton.Activated:Connect(ChangeSpeed)

controller.SongChanged.Event:Connect(function(song)
	if not song or not song.Name or not song.Id then
		return
	end

	-- Update favorite button
	if controller:IsFavorite(song) then
		favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 0)
	else
		favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end

	-- Update music icon & labels
	icon.Image = song.Icon
	namesBackground.MusicName.Text = song.Name
	namesBackground.ArtistName.Text = song.Artist
end)

-- Auto-play first song on load
PlayCurrent()

-- UI Buttons
playButton.Activated:Connect(function()
	if not isPlaying.Value then
		PlayCurrent()
	end
end)

pauseButton.Activated:Connect(function()
	if isPlaying.Value then
		PauseCurrent()
	end
end)

speakerMuteButton.Activated:Connect(function()
	controller.State.muted = true
	controller:SetVolume(false)
	speakerMuteButton.Visible = false
	speakerUnmuteButton.Visible = true
end)

speakerUnmuteButton.Activated:Connect(function()
	controller.State.muted = false
	controller:SetVolume(true)
	speakerMuteButton.Visible = true
	speakerUnmuteButton.Visible = false
end)

nextButton.Activated:Connect(function()
	controller:Next()
	controller.State.pausedPosition = 0
	isPlaying.Value = true
	RenderFavorite()
end)

prevButton.Activated:Connect(function()
	controller:Previous()
	controller.State.pausedPosition = 0
	isPlaying.Value = true
	RenderFavorite()
end)

local DURATION = 0.25
local animIds = {} -- target -> id

local UIState = {
	Open = false,
	Animating = false,
}

local function easeOutQuad(t)
	return 1 - (1 - t) * (1 - t)
end

-- Persistent storage of original transparency
local originalTransparency = {} -- GuiObject -> {property = value}

-- Persistent storage of original transparency
local originalTransparency = {} -- GuiObject -> {property = value}

local function animateToY(target, originX, targetY, state)
	local startY = target.Position.Y.Scale
	if math.abs(startY - targetY) < 0.001 then
		return
	end

	-- Determine if fading is needed
	local fade = state == "In" or state == "Out"

	-- Cache all gui objects with the correct transparency property
	local guiObjects = {}
	if fade then
		for _, obj in ipairs(target:GetDescendants()) do
			if obj:IsA("Frame") then
				table.insert(guiObjects, { obj = obj, prop = "BackgroundTransparency" })
				originalTransparency[obj] = originalTransparency[obj]
					or { BackgroundTransparency = obj.BackgroundTransparency }
			elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				table.insert(guiObjects, { obj = obj, prop = "ImageTransparency" })
				originalTransparency[obj] = originalTransparency[obj] or { ImageTransparency = obj.ImageTransparency }
			elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
				table.insert(guiObjects, { obj = obj, prop = "TextTransparency" })
				originalTransparency[obj] = originalTransparency[obj] or { TextTransparency = obj.TextTransparency }
			end
		end
	end

	animIds[target] = (animIds[target] or 0) + 1
	local id = animIds[target]
	local elapsed = 0

	while elapsed < DURATION do
		if animIds[target] ~= id then
			return
		end

		local dt = Services.GetService.RS.RenderStepped:Wait()
		elapsed += dt
		local t = math.clamp(elapsed / DURATION, 0, 1)
		local alpha = easeOutQuad(t)

		-- Slide animation
		local y = startY + (targetY - startY) * alpha
		target.Position = UDim2.new(originX, 0, y, 0)

		-- Fade animation
		if fade then
			for _, entry in ipairs(guiObjects) do
				local obj = entry.obj
				local prop = entry.prop
				local orig = originalTransparency[obj][prop]

				-- Target transparency based on state
				local targetAlpha = (state == "Out") and 1 or orig
				obj[prop] = orig + (targetAlpha - orig) * alpha
			end
		end
	end

	-- Snap final position & transparency
	target.Position = UDim2.new(originX, 0, targetY, 0)
	if fade then
		for _, entry in ipairs(guiObjects) do
			local obj = entry.obj
			local prop = entry.prop
			local orig = originalTransparency[obj][prop]
			local targetAlpha = (state == "Out") and 1 or orig
			obj[prop] = targetAlpha
		end
	end
end

local function animateToRot(target, targetRot)
	if not target then
		return
	end

	if math.abs(target.Rotation - targetRot) < 0.01 then
		return
	end

	animIds[target] = (animIds[target] or 0) + 1
	local id = animIds[target]

	local startRot = target.Rotation
	local elapsed = 0

	task.spawn(function()
		while elapsed < DURATION do
			if animIds[target] ~= id then
				return
			end

			local dt = Services.GetService.RS.RenderStepped:Wait()
			elapsed += dt
			local t = math.clamp(elapsed / DURATION, 0, 1)
			local alpha = easeOutQuad(t)

			target.Rotation = startRot + (targetRot - startRot) * alpha
		end
	end)

	target.Rotation = targetRot
end

local function animatePopup()
	local temp = favoriteButton:Clone()
	temp.Parent = favoriteBackground
	temp.AnchorPoint = Vector2.new(0.5, 0.5)
	temp.Position = favoriteButton.Position

	temp.Rotation = Services.Random(-30, 30)

	local startSize = temp.Size
	local elapsed = 0

	while elapsed < DURATION do
		elapsed += Services.GetService.RS.RenderStepped:Wait()
		local t = math.clamp(elapsed / DURATION, 0, 1)
		local alpha = easeOutQuad(t)

		local scale = 1 + (5 - 1) * alpha
		temp.Size = UDim2.fromScale(startSize.X.Scale * scale, startSize.Y.Scale * scale)

		temp.ImageTransparency = alpha
	end

	temp:Destroy()
end

function ToggleFavorite(Song)
	local song = Song or controller.State.songs[controller.State.index]
	if not song or typeof(song) ~= "table" then
		return
	end
	remotes.AddFavorite:FireServer({
		Name = song.Name,
		Id = tonumber(song.Id:match("%d+")),
	})

	if controller:IsFavorite(song) then
		controller:RemoveFavorite(song)
	else
		controller:AddFavorite(song)

		if song == controller.State.songs[controller.State.index] then
			task.spawn(animatePopup)
		end
	end

	RenderFavorite()
	RefreshList(nil)
end

musicButton.MouseEnter:Connect(function()
	if not musicButtonBackground then
		return
	end
	if UIState.Open then
		return
	end

	animateToY(musicButton, 0.5, 0.8)
end)

musicButton.MouseLeave:Connect(function()
	if not musicButtonBackground then
		return
	end
	if UIState.Open then
		return
	end

	animateToY(musicButton, 0.5, 1)
end)

musicButton.Activated:Connect(function()
	if UIState.Animating then
		return
	end
	UIState.Animating = true

	if not UIState.Open then
		-- OPEN
		UIState.Open = true
		layout.Visible = true

		task.spawn(function()
			animateToY(layout, 1, 1, "In")
		end)
		task.spawn(function()
			animateToY(musicButton, 0.5, 1, "In")
		end)

		task.delay(DURATION, function()
			UIState.Animating = false
		end)
	else
		-- CLOSE
		UIState.Open = false

		if listLayout.Visible then
			listLayout.Visible = false
		end

		task.spawn(function()
			animateToY(layout, 1, 2, "Out")
		end)
		task.spawn(function()
			animateToY(musicButton, 0.5, 1, "Out")
		end)

		task.delay(DURATION, function()
			layout.Visible = false
			UIState.Animating = false
		end)
	end
end)

listButton.Activated:Connect(function()
	if listLayout.Visible then
		-- CLOSE

		animateToRot(listButtonBackground, 0)
		listLayout.Visible = false

		for _, child in ipairs(listContainer:GetChildren()) do
			if child:IsA("ImageButton") then
				child.Visible = false
			end
		end
	else
		-- OPEN
		listLayout.Visible = true

		RefreshList(nil)
		animateToRot(listButtonBackground, -90)

		RefreshList(nil)
		animateToRot(listButtonBackground, -90)
	end
end)

listSearchBar:GetPropertyChangedSignal("Text"):Connect(function()
	RefreshList(listSearchBar.Text)
end)

listFavorite.Activated:Connect(function()
	local enable = not isFavorite.Value

	if enable then
		controller:SetPlaylistDeferred("Favorites")
		listFavorite.ImageColor3 = Color3.fromRGB(255, 255, 0)
		isFavorite.Value = true
	else
		controller:SetPlaylistDeferred("Regular")
		listFavorite.ImageColor3 = Color3.fromRGB(255, 255, 255)
		isFavorite.Value = false
	end

	RefreshList(nil)
end)

favoriteButton.Activated:Connect(function()
	ToggleFavorite(nil)
end)

layout.MouseEnter:Connect(function()
	hovered = true
end)

layout.MouseLeave:Connect(function()
	hovered = false
end)

local function Drag()
	if holding == false then
		moveCon:Disconnect()
		return
	end

	local distanceMovedX = initialX - mouse.X
	local distanceMovedY = initialY - mouse.Y

	background.Position = background.Position:Lerp(initialUIPos - UDim2.new(0, distanceMovedX, 0, distanceMovedY), 0.2)
end

Services.GetService.uis.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = hovered
		if holding then
			initialX, initialY = mouse.X, mouse.Y
			initialUIPos = background.Position

			moveCon = mouse.Move:Connect(Drag)
		end
	end
end)

Services.GetService.uis.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)

for i = 1, MusicConfigs.Markers do
	local bar = assets.UI.Bar:Clone()
	bar.LayoutOrder = i
	bar.Name = tostring(i)

	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(bar.Position.X.Scale, 0.5)

	bar:SetAttribute("BaseSize", bar.Size)

	bar.Parent = visualizerContainer
end

Services.GetService.RS.RenderStepped:Connect(function(dt)
	local spectrum = controller.Sound.AudioAnalyzer:GetSpectrum()

	for _, bar in ipairs(visualizerContainer:GetChildren()) do
		if not bar:IsA("Frame") then
			continue
		end

		local baseSize = bar:GetAttribute("BaseSize")
		if not baseSize then
			continue
		end

		local amplitude = spectrum[bar.LayoutOrder] or 0
		local scale = amplitude / 0.03

		local targetSize = baseSize + UDim2.fromScale(0, scale < 0.2 and 0.2 or scale)

		bar.Size = bar.Size:Lerp(targetSize, math.min(1, dt * 10))
	end
end)

while true do
	playButton.Visible = not isPlaying.Value
	pauseButton.Visible = isPlaying.Value

	-- Update time tracking
	if isPlaying.Value and controller.Sound.IsPlaying then
		local currentTime = controller.Sound.TimePosition
		local totalTime = controller.Sound.TimeLength

		timePlayed.Value = currentTime
		timeRemain.Value = math.max(0, totalTime - currentTime)

		if currentTime > 0 then
			local progress = currentTime / totalTime

			progressBar.Size = UDim2.new(progress, 0, 1, 0)
			visualizerProgressBar.Size = UDim2.new(progress, 0, 1, 0)
		end
	end

	-- Update UI text only
	if timeBackground then
		timeBackground.TimePlayed.Text = formatTime(timePlayed.Value)
		timeBackground.TimeRemain.Text = formatTime(timeRemain.Value)
	end

	task.wait(0.1)
end
