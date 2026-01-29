local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local shared = Services.GetService.rs.Shared
local remotes = Services.GetService.rs.Remotes

local MusicModules = shared.MusicPlayer
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

local MusicMain = {}
MusicMain.__index = MusicMain

function MusicMain.Init()
	local self = setmetatable({}, MusicMain)

	self.hovered = false
	self.holding = false
	self.moveCon = nil

	self.initialX = 0
	self.initialY = 0
	self.initialUIPos = nil

	self.speedEnums = {
		["1"] = 1.0,
		["2"] = 1.5,
		["3"] = 0.75,
	}

	self.speedOrder = { "1", "2", "3" } -- order of speed cycles
	self.speedIndex = 1 -- start at first speed

	self.templateConnections = {}
	self.templatePool = {}

	-- songs
	self.ALL_SONGS = {}

	local initialTotal = 0

	for _, song in ipairs(MusicConfigs.MusicList) do
		table.insert(self.ALL_SONGS, {
			Id = "rbxassetid://" .. song.SoundId,
			Name = song.MusicName,
			Artist = song.MusicArtist,
			Icon = song.AlbumIcon,
		})
		initialTotal += 1
	end

	table.sort(self.ALL_SONGS, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	self.SONG_INDEX_BY_ID = {}

	for i, song in ipairs(self.ALL_SONGS) do
		self.SONG_INDEX_BY_ID[song.Id] = i
	end

	local function cloneSongs(list)
		local copy = table.clone(list)
		return copy
	end

	local MusicState = {
		playlist = "Regular",
		pendingPlaylist = nil, -- "Favorites" | "Regular" | nil

		index = 1,
		total = initialTotal,

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
		songs = cloneSongs(self.ALL_SONGS),

		favorites = {},

		pausedPosition = 0, -- track position to resume
	}

	self.AnimDuration = 0.25
	self.animIds = {} -- target -> id

	self.UIState = {
		Open = false,
		Animating = false,
	}
	self.originalTransparency = {}

	local controller = MusicController.new(MusicState)
	controller._allSongs = MusicState.songs -- give it ALL_SONGS for regular playlist

	self.controller = controller

	self:Connections()
	self:Start()
	self:PlayCurrent(Services.RandomInteger(1, initialTotal))

	return self
end

function MusicMain:Start()
	local accum = 0
	Services.GetService.RS.RenderStepped:Connect(function(dt)
		accum += dt
		if accum < 0.1 then
			return
		end
		accum = 0

		playButton.Visible = not isPlaying.Value
		pauseButton.Visible = isPlaying.Value

		-- Update time tracking
		if isPlaying.Value and self.controller.Sound.IsPlaying then
			local currentTime = self.controller.Sound.TimePosition
			local totalTime = self.controller.Sound.TimeLength

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
			timeBackground.TimePlayed.Text = self.FormatTime(timePlayed.Value)
			timeBackground.TimeRemain.Text = self.FormatTime(timeRemain.Value)
		end

		task.wait(0.1)
	end)
end

function MusicMain.EaseOutQuad(t)
	return 1 - (1 - t) * (1 - t)
end

function MusicMain.Normalize(str)
	return str:lower():gsub("[%p%c]", ""):gsub("%s+", "")
end

function MusicMain:RenderFavorite()
	local song = self.controller.State.songs[self.controller.State.index]
	if not song then
		return
	end

	if self.controller:IsFavorite(song) then
		favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 0)
	else
		favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end

function MusicMain:ToggleMusicPlayer()
	if self.UIState.Animating then
		return
	end
	self.UIState.Animating = true

	if not self.UIState.Open then
		-- OPEN
		self.UIState.Open = true
		layout.Visible = true

		task.spawn(function()
			self:AnimateToY(layout, 1, 1, "In")
		end)
		task.spawn(function()
			self:AnimateToY(musicButton, 0.5, 1, "In")
		end)

		task.delay(self.AnimDuration, function()
			self.UIState.Animating = false
		end)
	else
		-- CLOSE
		self.UIState.Open = false

		if listLayout.Visible then
			listLayout.Visible = false
		end

		task.spawn(function()
			self:AnimateToY(layout, 1, 2, "Out")
		end)
		task.spawn(function()
			self:AnimateToY(musicButton, 0.5, 1, "Out")
		end)

		task.delay(self.AnimDuration, function()
			layout.Visible = false
			self.UIState.Animating = false
		end)
	end
end

function MusicMain:Connections()
	remotes.LoadFavorite.OnClientEvent:Connect(function(savedFavorites)
		self.controller.State.favorites = savedFavorites or {}
		self:RenderFavorite()
	end)

	remotes.LoadFavorite:FireServer()

	remotes.ToggleMusicPlayer.Event:Connect(function()
		self:ToggleMusicPlayer()
	end)

	musicButton.MouseEnter:Connect(function()
		if not musicButtonBackground then
			return
		end
		if self.UIState.Open then
			return
		end

		self:AnimateToY(musicButton, 0.5, 0.8)
	end)

	musicButton.MouseLeave:Connect(function()
		if not musicButtonBackground then
			return
		end
		if self.UIState.Open then
			return
		end

		self:AnimateToY(musicButton, 0.5, 1)
	end)

	musicButton.Activated:Connect(function()
		self:ToggleMusicPlayer()
	end)

	listButton.Activated:Connect(function()
		if listLayout.Visible then
			-- CLOSE

			self:AnimateToRot(listButtonBackground, 0)
			listLayout.Visible = false

			for _, child in ipairs(listContainer:GetChildren()) do
				if child:IsA("ImageButton") then
					child.Visible = false
				end
			end
		else
			-- OPEN
			listLayout.Visible = true

			self:RefreshList("")
			self:AnimateToRot(listButtonBackground, -90)

			self:RefreshList("")
			self:AnimateToRot(listButtonBackground, -90)
		end
	end)

	listSearchBar:GetPropertyChangedSignal("Text"):Connect(function()
		self:RefreshList(listSearchBar.Text)
	end)

	listFavorite.Activated:Connect(function()
		local enable = not isFavorite.Value

		if enable then
			self.controller:SetPlaylistDeferred("Favorites")
			listFavorite.ImageColor3 = Color3.fromRGB(255, 255, 0)
			isFavorite.Value = true
		else
			self.controller:SetPlaylistDeferred("Regular")
			listFavorite.ImageColor3 = Color3.fromRGB(255, 255, 255)
			isFavorite.Value = false
		end

		self:RefreshList("")
	end)

	favoriteButton.Activated:Connect(function()
		self:ToggleFavorite(nil)
	end)

	layout.MouseEnter:Connect(function()
		self.hovered = true
	end)

	layout.MouseLeave:Connect(function()
		self.hovered = false
	end)

	local function Drag()
		if self.holding == false then
			self.moveCon:Disconnect()
			return
		end

		local distanceMovedX = self.initialX - mouse.X
		local distanceMovedY = self.initialY - mouse.Y

		background.Position =
			background.Position:Lerp(self.initialUIPos - UDim2.new(0, distanceMovedX, 0, distanceMovedY), 0.5)
	end

	Services.GetService.uis.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.holding = self.hovered
			if self.holding then
				self.initialX, self.initialY = mouse.X, mouse.Y
				self.initialUIPos = background.Position

				self.moveCon = mouse.Move:Connect(Drag)
			end
		end
	end)

	Services.GetService.uis.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.holding = false
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
		local spectrum = self.controller.Sound.AudioAnalyzer:GetSpectrum()

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

	playButton.Activated:Connect(function()
		if not isPlaying.Value then
			self:PlayCurrent()
		end
	end)

	pauseButton.Activated:Connect(function()
		if isPlaying.Value then
			self:PauseCurrent()
		end
	end)

	speakerMuteButton.Activated:Connect(function()
		self.controller.State.muted = true
		self.controller:SetVolume(false)
		speakerMuteButton.Visible = false
		speakerUnmuteButton.Visible = true
	end)

	speakerUnmuteButton.Activated:Connect(function()
		self.controller.State.muted = false
		self.controller:SetVolume(true)
		speakerMuteButton.Visible = true
		speakerUnmuteButton.Visible = false
	end)

	nextButton.Activated:Connect(function()
		self.controller:Next()
		self.controller.State.pausedPosition = 0
		isPlaying.Value = true
		self:RenderFavorite()
	end)

	prevButton.Activated:Connect(function()
		self.controller:Previous()
		self.controller.State.pausedPosition = 0
		isPlaying.Value = true
		self:RenderFavorite()
	end)

	loopButton.Activated:Connect(function()
		self:ChangeLoopMode()
	end)
	shuffleButton.Activated:Connect(function()
		self:ChangeShuffleMode()
	end)
	speedButton.Activated:Connect(function()
		self:ChangeSpeed()
	end)

	self.controller.SongChanged.Event:Connect(function(song)
		if not song or not song.Name or not song.Id then
			return
		end

		-- Update favorite button
		if self.controller:IsFavorite(song) then
			favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 0)
		else
			favoriteButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
		end

		-- Update music icon & labels
		icon.Image = song.Icon
		namesBackground.MusicName.Text = song.Name
		namesBackground.ArtistName.Text = song.Artist
	end)
end

function MusicMain:ClearTemplate(template)
	if self.templateConnections[template] then
		self.templateConnections[template]:Disconnect()
		self.templateConnections[template] = nil
	end
	if self.templateConnections[template.Favorite] then
		self.templateConnections[template.Favorite]:Disconnect()
		self.templateConnections[template.Favorite] = nil
	end
end

function MusicMain:GetTemplate()
	for _, t in ipairs(self.templatePool) do
		if not t.Parent then
			return t
		end
	end
	local template = assets.UI.MusicTemplate:Clone()
	table.insert(self.templatePool, template)
	return template
end

function MusicMain:RefreshList(searchText)
	searchText = searchText or ""

	local normalizedSearch = self.Normalize(searchText)

	for _, child in ipairs(listContainer:GetChildren()) do
		if child:IsA("ImageButton") then
			child.Parent = nil -- remove from container for reuse
		end
	end

	local startsWith = {}
	local contains = {}

	local songs = self.controller.State.songs

	for _, info in ipairs(songs) do
		if normalizedSearch == "" then
			table.insert(contains, info)
		else
			local normalizedName = self.Normalize(info.Name)

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
		local template = self:GetTemplate()
		self:ClearTemplate(template)

		template.Parent = listContainer
		template.LayoutOrder = i
		template.Visible = true

		local favorite = self.controller:CheckFavorite(info)

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
		self.templateConnections[template] = template.Activated:Connect(function()
			self.controller.State.index = songIndex
			self.controller.State.pausedPosition = 0
			self.controller:Play(info)
			isPlaying.Value = true
		end)

		self.templateConnections[template.Favorite] = template.Favorite.Activated:Connect(function()
			self:ToggleFavorite(songs[songIndex])
		end)
	end
end

-- Modified Play function to support resume
function MusicMain:PlayCurrent(songIndex)
	local song = self.controller.State.songs[songIndex] or self.controller.State.songs[self.controller.State.index]
	if not song then
		return
	end

	if songIndex and songIndex ~= 0 then
		self.controller.State.index = songIndex
	end

	self.controller:Play(song)

	if self.controller.Sound then
		self.controller.Sound.TimePosition = self.controller.State.pausedPosition or 0
	end

	self.controller.State.paused = false
	isPlaying.Value = true

	self:RenderFavorite()
end

-- Modified Pause function to store position
function MusicMain:PauseCurrent()
	self.controller.State.pausedPosition = self.controller.Sound.TimePosition
	self.controller:Pause()
	self.controller.State.paused = true
	isPlaying.Value = false
end

function MusicMain:ChangeLoopMode()
	self.controller:SetLoop(not self.controller.State.looped)
	if self.controller.State.looped then
		loopButton.ImageColor3 = Color3.fromRGB(0, 255, 0) -- active
	else
		loopButton.ImageColor3 = Color3.fromRGB(255, 255, 255) -- inactive
	end
end

function MusicMain:ChangeShuffleMode()
	self.controller:SetShuffle(not self.controller.State.shuffle)
	if self.controller.State.shuffle then
		shuffleButton.ImageColor3 = Color3.fromRGB(0, 255, 0) -- active
	else
		shuffleButton.ImageColor3 = Color3.fromRGB(255, 255, 255) -- inactive
	end
end

function MusicMain:ChangeSpeed()
	self.speedIndex += 1
	if self.speedIndex > #self.speedOrder then
		self.speedIndex = 1
	end

	local speedKey = self.speedOrder[self.speedIndex]
	local speedValue = self.speedEnums[speedKey]

	-- Update controller state

	self.controller:SetSpeed(speedKey, speedValue)

	-- Update UI
	speedButton.Text = speedValue .. "x"
end

-- Helper for formatting time
function MusicMain.FormatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

function MusicMain:AnimateToY(target, originX, targetY, state)
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
				self.originalTransparency[obj] = self.originalTransparency[obj]
					or { BackgroundTransparency = obj.BackgroundTransparency }
			elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				table.insert(guiObjects, { obj = obj, prop = "ImageTransparency" })
				self.originalTransparency[obj] = self.originalTransparency[obj]
					or { ImageTransparency = obj.ImageTransparency }
			elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
				table.insert(guiObjects, { obj = obj, prop = "TextTransparency" })
				self.originalTransparency[obj] = self.originalTransparency[obj]
					or { TextTransparency = obj.TextTransparency }
			end
		end
	end

	self.animIds[target] = (self.animIds[target] or 0) + 1
	local id = self.animIds[target]
	local elapsed = 0

	while elapsed < self.AnimDuration do
		if self.animIds[target] ~= id then
			return
		end

		local dt = Services.GetService.RS.RenderStepped:Wait()
		elapsed += dt
		local t = math.clamp(elapsed / self.AnimDuration, 0, 1)
		local alpha = self.EaseOutQuad(t)

		-- Slide animation
		local y = startY + (targetY - startY) * alpha
		target.Position = UDim2.new(originX, 0, y, 0)

		-- Fade animation
		if fade then
			for _, entry in ipairs(guiObjects) do
				local obj = entry.obj
				local prop = entry.prop
				local orig = self.originalTransparency[obj][prop]

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
			local orig = self.originalTransparency[obj][prop]
			local targetAlpha = (state == "Out") and 1 or orig
			obj[prop] = targetAlpha
		end
	end
end

function MusicMain:AnimateToRot(target, targetRot)
	if not target then
		return
	end

	if math.abs(target.Rotation - targetRot) < 0.01 then
		return
	end

	self.animIds[target] = (self.animIds[target] or 0) + 1
	local id = self.animIds[target]

	local startRot = target.Rotation
	local elapsed = 0

	task.spawn(function()
		while elapsed < self.AnimDuration do
			if self.animIds[target] ~= id then
				return
			end

			local dt = Services.GetService.RS.RenderStepped:Wait()
			elapsed += dt
			local t = math.clamp(elapsed / self.AnimDuration, 0, 1)
			local alpha = self.EaseOutQuad(t)

			target.Rotation = startRot + (targetRot - startRot) * alpha
		end
	end)

	target.Rotation = targetRot
end

function MusicMain:AnimatePopup()
	local temp = favoriteButton:Clone()
	temp.Parent = favoriteBackground
	temp.AnchorPoint = Vector2.new(0.5, 0.5)
	temp.Position = favoriteButton.Position

	temp.Rotation = Services.RandomInteger(-30, 30)

	local startSize = temp.Size
	local elapsed = 0

	while elapsed < self.AnimDuration do
		elapsed += Services.GetService.RS.RenderStepped:Wait()
		local t = math.clamp(elapsed / self.AnimDuration, 0, 1)
		local alpha = self.EaseOutQuad(t)

		local scale = 1 + (5 - 1) * alpha
		temp.Size = UDim2.fromScale(startSize.X.Scale * scale, startSize.Y.Scale * scale)

		temp.ImageTransparency = alpha
	end

	temp:Destroy()
end

function MusicMain:ToggleFavorite(Song)
	local song = Song or self.controller.State.songs[self.controller.State.index]
	if not song or typeof(song) ~= "table" then
		return
	end
	remotes.AddFavorite:FireServer({
		Name = song.Name,
		Id = tonumber(song.Id:match("%d+")),
	})

	if self.controller:IsFavorite(song) then
		self.controller:RemoveFavorite(song)
	else
		self.controller:AddFavorite(song)

		if song == self.controller.State.songs[self.controller.State.index] then
			task.spawn(function()
				self:AnimatePopup()
			end)
		end
	end

	self:RenderFavorite()
	self:RefreshList("")
end

return MusicMain
