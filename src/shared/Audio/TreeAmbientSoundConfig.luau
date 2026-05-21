--!strict

export type TreeAmbientSoundConfig = {
	soundName: string,
	currentVisualModelName: string,
	fullVolumeDistanceStuds: number,
	startDistanceStuds: number,
	stopDistanceStuds: number,
	rollOffMinDistanceStuds: number,
	rollOffMaxDistanceStuds: number,
	updateIntervalSeconds: number,
}

local TreeAmbientSoundConfig: TreeAmbientSoundConfig = table.freeze({
	soundName = "Sound",
	currentVisualModelName = "CurrentVisual",
	fullVolumeDistanceStuds = 5,
	startDistanceStuds = 20,
	stopDistanceStuds = 24,
	rollOffMinDistanceStuds = 4,
	rollOffMaxDistanceStuds = 20,
	updateIntervalSeconds = 0.25,
})

return TreeAmbientSoundConfig
