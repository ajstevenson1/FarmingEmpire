--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared") :: Folder
local audioFolder = sharedFolder:WaitForChild("Audio") :: Folder

local AudioBus = require(audioFolder:WaitForChild("AudioBus") :: ModuleScript)

type AudioBusId = AudioBus.AudioBusId

export type AudioService = {
	start: () -> (),
	getOrCreateSoundGroup: (busId: AudioBusId) -> SoundGroup,
	assignSoundToBus: (sound: Sound, busId: AudioBusId) -> SoundGroup,
	setBusVolume: (busId: AudioBusId, volume: number) -> (),
}

local hasStarted = false
local soundGroupsByBusId: { [AudioBusId]: SoundGroup } = {}

local function getExistingSoundGroup(busId: AudioBusId): SoundGroup?
	local existing = SoundService:FindFirstChild(busId)
	if existing == nil then
		return nil
	end

	assert(existing:IsA("SoundGroup"), string.format("SoundService.%s must be a SoundGroup", busId))
	return existing
end

local AudioService = {} :: AudioService

function AudioService.getOrCreateSoundGroup(busId: AudioBusId): SoundGroup
	local cached = soundGroupsByBusId[busId]
	if cached ~= nil then
		return cached
	end

	local existing = getExistingSoundGroup(busId)
	if existing ~= nil then
		soundGroupsByBusId[busId] = existing
		return existing
	end

	local created = Instance.new("SoundGroup")
	created.Name = busId
	created.Volume = 1
	created.Parent = SoundService
	soundGroupsByBusId[busId] = created
	return created
end

function AudioService.assignSoundToBus(sound: Sound, busId: AudioBusId): SoundGroup
	local soundGroup = AudioService.getOrCreateSoundGroup(busId)
	sound.SoundGroup = soundGroup
	return soundGroup
end

function AudioService.setBusVolume(busId: AudioBusId, volume: number)
	local soundGroup = AudioService.getOrCreateSoundGroup(busId)
	soundGroup.Volume = math.clamp(volume, 0, 1)
end

function AudioService.start()
	if hasStarted then
		return
	end

	hasStarted = true

	for _, busId in ipairs(AudioBus.getAllBusIds()) do
		AudioService.getOrCreateSoundGroup(busId)
	end
end

return table.freeze(AudioService)
