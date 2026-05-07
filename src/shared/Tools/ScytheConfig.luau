--!strict

export type SoundEffectConfig = {
	soundId: string,
	volume: number,
	playbackSpeed: number,
}

export type ScytheConfig = {
	cooldownSeconds: number,
	swingHalfAngleDegrees: number,
	swingRange: number,
	swingVerticalTolerance: number,
	sounds: {
		swing: SoundEffectConfig,
		harvestConfirm: SoundEffectConfig,
	},
}

local ScytheConfig: ScytheConfig = table.freeze({
	cooldownSeconds = 0.5,
	swingHalfAngleDegrees = 60,
	swingRange = 7,
	swingVerticalTolerance = 6,
	sounds = table.freeze({
		swing = table.freeze({
			soundId = "rbxassetid://104490557113914",
			volume = 1,
			playbackSpeed = 1,
		}),
		harvestConfirm = table.freeze({
			soundId = "rbxassetid://95295329524170",
			volume = 1,
			playbackSpeed = 1,
		}),
	}),
})

return ScytheConfig
