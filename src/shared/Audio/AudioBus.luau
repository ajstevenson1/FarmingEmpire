--!strict

export type AudioBusId = "Music" | "SFX"

local allAudioBusIds: { AudioBusId } = table.freeze({
	"Music",
	"SFX",
})

local AudioBus = {}

function AudioBus.getAllBusIds(): { AudioBusId }
	return allAudioBusIds
end

return table.freeze(AudioBus)
