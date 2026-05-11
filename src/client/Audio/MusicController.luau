--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local audioFolder = sharedFolder:WaitForChild("Audio") :: Folder

local AudioService = require(script.Parent.AudioService)
local MusicPlaylist = require(audioFolder:WaitForChild("MusicPlaylist") :: ModuleScript)

type MusicTrackId = MusicPlaylist.MusicTrackId

local MUSIC_SOUND_NAME = "BackgroundMusic"

local hasStarted = false
local randomGenerator = Random.new()
local musicSound: Sound? = nil
local queuedTrackIds: { MusicTrackId } = {}
local lastPlayedTrackId: MusicTrackId? = nil

local function getOrCreateMusicSound(): Sound
	local existing = SoundService:FindFirstChild(MUSIC_SOUND_NAME)
	if existing ~= nil then
		assert(existing:IsA("Sound"), string.format("SoundService.%s must be a Sound", MUSIC_SOUND_NAME))
		existing.Looped = false
		existing.Volume = 1
		AudioService.assignSoundToBus(existing, "Music")
		return existing
	end

	local created = Instance.new("Sound")
	created.Name = MUSIC_SOUND_NAME
	created.Looped = false
	created.Volume = 1
	AudioService.assignSoundToBus(created, "Music")
	created.Parent = SoundService
	return created
end

local function shuffleTrackIds(trackIds: { MusicTrackId }): { MusicTrackId }
	local shuffledTrackIds = table.clone(trackIds)
	for index = #shuffledTrackIds, 2, -1 do
		local swapIndex = randomGenerator:NextInteger(1, index)
		shuffledTrackIds[index], shuffledTrackIds[swapIndex] = shuffledTrackIds[swapIndex], shuffledTrackIds[index]
	end

	local priorTrackId = lastPlayedTrackId
	if priorTrackId ~= nil and #shuffledTrackIds > 1 and shuffledTrackIds[1] == priorTrackId then
		shuffledTrackIds[1], shuffledTrackIds[#shuffledTrackIds] = shuffledTrackIds[#shuffledTrackIds], shuffledTrackIds[1]
	end

	return shuffledTrackIds
end

local function refillQueueIfNeeded()
	if #queuedTrackIds > 0 then
		return
	end

	queuedTrackIds = shuffleTrackIds(MusicPlaylist.getTrackIds())
end

local function playNextTrack()
	local sound = musicSound
	if sound == nil then
		return
	end

	refillQueueIfNeeded()
	if #queuedTrackIds == 0 then
		warn("[MusicController] No music tracks are configured.")
		return
	end

	local nextTrackId = table.remove(queuedTrackIds, 1)
	assert(nextTrackId ~= nil, "Music queue unexpectedly returned nil")
	lastPlayedTrackId = nextTrackId

	sound:Stop()
	sound.SoundId = nextTrackId
	sound.TimePosition = 0
	sound:Play()
end

local MusicController = {}

function MusicController.start()
	if hasStarted then
		return
	end

	hasStarted = true
	AudioService.start()
	musicSound = getOrCreateMusicSound()

	local trackIds = MusicPlaylist.getTrackIds()
	if #trackIds == 0 then
		warn("[MusicController] Music playlist is empty.")
		return
	end

	musicSound.Ended:Connect(function()
		playNextTrack()
	end)

	playNextTrack()
end

return table.freeze(MusicController)
