--!strict

local SoundService = game:GetService("SoundService")

local AudioService = require(script.Parent.Parent.Audio.AudioService)

type SoundKey = "Cash" | "Cider"

export type ResourceGainSoundPlayer = {
	playCashEarned: (self: ResourceGainSoundPlayer) -> (),
	playCiderCollected: (self: ResourceGainSoundPlayer) -> (),
	destroy: (self: ResourceGainSoundPlayer) -> (),
}

local SOUND_IDS_BY_KEY: { [SoundKey]: string } = {
	Cash = "rbxassetid://124075090375862",
	Cider = "rbxassetid://72594702113966",
}

local SOUND_NAME_BY_KEY: { [SoundKey]: string } = {
	Cash = "CashEarnedSound",
	Cider = "CiderCollectedSound",
}

local ResourceGainSoundPlayer = {}
ResourceGainSoundPlayer.__index = ResourceGainSoundPlayer

local function getOrCreateSound(soundKey: SoundKey): Sound
	local soundName = SOUND_NAME_BY_KEY[soundKey]
	local existing = SoundService:FindFirstChild(soundName)
	if existing ~= nil then
		assert(existing:IsA("Sound"), string.format("SoundService.%s must be a Sound", soundName))
		existing.SoundId = SOUND_IDS_BY_KEY[soundKey]
		existing.Volume = 1
		existing.PlaybackSpeed = 1
		existing.Looped = false
		AudioService.assignSoundToBus(existing, "SFX")
		return existing
	end

	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.SoundId = SOUND_IDS_BY_KEY[soundKey]
	sound.Volume = 1
	sound.PlaybackSpeed = 1
	sound.Looped = false
	AudioService.assignSoundToBus(sound, "SFX")
	sound.Parent = SoundService
	return sound
end

local function playSound(soundKey: SoundKey)
	local sound = getOrCreateSound(soundKey)
	if sound.IsPlaying then
		return
	end

	sound.TimePosition = 0
	sound:Play()
end

function ResourceGainSoundPlayer.new(): ResourceGainSoundPlayer
	AudioService.start()

	local self = setmetatable({}, ResourceGainSoundPlayer) :: ResourceGainSoundPlayer
	return self
end

function ResourceGainSoundPlayer:playCashEarned()
	playSound("Cash")
end

function ResourceGainSoundPlayer:playCiderCollected()
	playSound("Cider")
end

function ResourceGainSoundPlayer:destroy()
end

return ResourceGainSoundPlayer
