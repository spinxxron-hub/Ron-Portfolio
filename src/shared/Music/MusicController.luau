local Services = require(game:GetService("ReplicatedStorage").Shared.Services)
local SoundService = Services.GetService.SS

local MusicController = {}
MusicController.__index = MusicController

--// Constructor
function MusicController.new(state)
	local self = setmetatable({}, MusicController)
	self.State = state

	self.SongChanged = Instance.new("BindableEvent")

	self.Sound = SoundService:FindFirstChild("Music") or Instance.new("Sound")
	self.Sound.Name = "Music"
	self.Sound.Parent = SoundService

	self:_bindEnded()
	return self
end

--// Song ended behavior
function MusicController:_bindEnded()
	self.Sound.Ended:Connect(function()
		self.State.pausedPosition = 0

		if self.State.looped then
			self.Sound.TimePosition = 0
			self:Play(self.State.songs[self.State.index])
		else
			self:_commitPendingPlaylist()
			self:Next()
		end
	end)
end

--// =========================
--// Playlist Controls
--// =========================

function MusicController:_buildFavoritesList()
	local list = {}

	for _, song in ipairs(self.State.songs) do
		if self:IsFavorite(song) then
			table.insert(list, song)
		end
	end

	table.sort(list, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	return list
end

function MusicController:_commitPendingPlaylist()
	local pending = self.State.pendingPlaylist
	if not pending then
		return
	end

	local currentSong = self.State.songs[self.State.index]

	if pending == "Favorites" then
		local favs = self:_buildFavoritesList()
		if #favs == 0 then
			self.State.pendingPlaylist = nil
			return
		end

		self.State.songs = favs
		self.State.playlist = "Favorites"
	else
		-- Use original ALL_SONGS from your main script
		if self._allSongs then
			self.State.songs = self._allSongs
		else
			warn("[MusicController] No reference to ALL_SONGS")
			return
		end
		self.State.playlist = "Regular"
	end

	-- Keep current song if it exists in new list
	local newIndex = table.find(self.State.songs, currentSong)
	self.State.index = newIndex or 1

	self.State.pendingPlaylist = nil
end

function MusicController:SetPlaylistDeferred(mode)
	if self.State.playlist == mode then
		return false
	end

	self.State.pendingPlaylist = mode

	-- commit immediately
	self:_commitPendingPlaylist()

	return true
end

--// =========================
--// Playback Controls
--// =========================

function MusicController:Play(song)
	if not song then
		return
	end

	if self.Sound.Asset ~= song.Id then
		self.Sound.Asset = song.Id
	end

	self.Sound.Volume = self.State.muted and 0 or (self.State.volume or 1)
	self.Sound.TimePosition = self.State.pausedPosition or 0
	self.Sound:Play()

	self.SongChanged:Fire(song)

	self.State.paused = false
end

function MusicController:Pause()
	self.State.pausedPosition = self.Sound.TimePosition
	self.Sound:Stop()
	self.State.paused = true
end

--// =========================
--// Loop
--// =========================

function MusicController:SetLoop(enabled)
	self.State.looped = enabled
	self.Sound.Looping = enabled
end

--// =========================
--// Volume (smooth fade, tap-safe)
--// =========================

function MusicController:SetVolume(muted)
	if not self.Sound then
		return
	end

	local targetVolume = muted and 0 or (self.State.volume or 1)
	local step = 0.05
	local delay = 0.02

	if self._fadeTask then
		task.cancel(self._fadeTask)
	end

	self._fadeTask = task.spawn(function()
		while math.abs(self.Sound.Volume - targetVolume) > 0.01 do
			local dir = targetVolume > self.Sound.Volume and 1 or -1
			self.Sound.Volume = math.clamp(self.Sound.Volume + step * dir, 0, 1)
			task.wait(delay)
		end
		self.Sound.Volume = targetVolume
		self._fadeTask = nil
	end)

	self.State.muted = muted
end

--// =========================
--// Playback Speed (smooth)
--// =========================

function MusicController:SetSpeed(speedKey, speedValue)
	if not self.Sound then
		return
	end

	if self._speedFadeTask then
		task.cancel(self._speedFadeTask)
	end

	self.State.CurrentSpeed = speedKey

	self._speedFadeTask = task.spawn(function()
		local step = 0.05
		local delay = 0.02

		while math.abs(self.Sound.PlaybackSpeed - speedValue) > 0.01 do
			local dir = speedValue > self.Sound.PlaybackSpeed and 1 or -1
			self.Sound.PlaybackSpeed = math.clamp(self.Sound.PlaybackSpeed + step * dir, 0.1, 10)
			task.wait(delay)
		end

		self.Sound.PlaybackSpeed = speedValue
		self._speedFadeTask = nil
	end)
end

--// =========================
--// Shuffle (index-safe)
--// =========================

local function generateShuffleOrder(count)
	local order = {}
	for i = 1, count do
		order[i] = i
	end

	for i = count, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end

	return order
end

function MusicController:SetShuffle(enabled)
	if self.State.shuffle == enabled then
		return
	end

	self.State.shuffle = enabled

	if enabled then
		self.State.shuffleOrder = generateShuffleOrder(#self.State.songs)

		local current = self.State.index
		local pos = table.find(self.State.shuffleOrder, current)
		if pos then
			table.remove(self.State.shuffleOrder, pos)
		end

		table.insert(self.State.shuffleOrder, 1, current)
		self.State.shuffleIndex = 1
	else
		self.State.shuffleOrder = {}
		self.State.shuffleIndex = 1
	end
end

function MusicController:SetPlaylist(mode, ALL_SONGS, SONG_INDEX_BY_ID, cloneSongs)
	if mode == "Favorites" then
		local favs = self:GetFavoritesArray()
		if #favs == 0 then
			return false -- nothing to play
		end

		self.State.playlist = "Favorites"
		self.State.songs = favs
		self.State.index = 1
	else
		self.State.playlist = "Regular"
		self.State.songs = cloneSongs(ALL_SONGS)
		self.State.index = SONG_INDEX_BY_ID[self.Sound.Asset] or 1
	end

	self.State.pausedPosition = 0
	return true
end

--// =========================
--// Track Navigation
--// =========================

function MusicController:Next()
	self:_commitPendingPlaylist()

	if self.State.shuffle then
		self.State.shuffleIndex += 1
		if self.State.shuffleIndex > #self.State.shuffleOrder then
			self.State.shuffleIndex = 1
		end
		self.State.index = self.State.shuffleOrder[self.State.shuffleIndex]
	else
		self.State.index += 1
		if self.State.index > #self.State.songs then
			self.State.index = 1
		end
	end

	self.State.pausedPosition = 0
	self:Play(self.State.songs[self.State.index])
end

function MusicController:Previous()
	self:_commitPendingPlaylist()

	self.State.index -= 1
	if self.State.index < 1 then
		self.State.index = #self.State.songs
	end

	self.State.pausedPosition = 0
	self:Play(self.State.songs[self.State.index])
end

--// =========================
--// Favorites (ID/Name-based, safe)
--// =========================

function MusicController:CheckFavorite(songInfo)
	local existFavorite = self.State.favorites[songInfo.Name]

	if existFavorite then
		if songInfo.Id == existFavorite.Id then
			return true
		end
	end

	return false
end

function MusicController:IsFavorite(songInfo)
	if not songInfo then
		return
	end
	return self:CheckFavorite(songInfo)
end

function MusicController:AddFavorite(songInfo)
	if not songInfo then
		return
	end

	local isFavorite = self:IsFavorite(songInfo)

	if not isFavorite then
		self.State.favorites[songInfo.Name] = {
			Id = songInfo.Id,
		}
		return true
	end

	return false
end

function MusicController:RemoveFavorite(songInfo)
	if not songInfo then
		return
	end

	local isFavorite = self:IsFavorite(songInfo)

	if isFavorite then
		local existFavorite = self:CheckFavorite(songInfo)

		if existFavorite then
			self.State.favorites[songInfo.Name] = nil
			return true
		end
	end

	return false
end

--// =========================
--// UI-only helper
--// =========================

function MusicController:GetFavoritesList()
	return self.State.favorites
end

-- optional: return a sorted array of favorite song tables

function MusicController:GetFavoritesArray()
	local arr = {}
	for _, song in ipairs(self.State.songs) do
		if self:IsFavorite(song) then
			table.insert(arr, song)
		end
	end
	table.sort(arr, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)
	return arr
end

function MusicController:GetCurrentList()
	if self.State.playlist == "Favorites" then
		return self:GetFavoritesArray()
	end
	return self.State.songs
end

return MusicController
